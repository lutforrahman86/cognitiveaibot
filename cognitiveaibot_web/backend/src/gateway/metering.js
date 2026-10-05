/**
 * Credits and per-request metering for model calls.
 *
 * Every call follows hold → call → settle:
 *   1. start(): reserve the worst-case cost from the user's available
 *      credits (refused with 402 if they can't cover a minimal reply) and
 *      open a request_logs row.
 *   2. The provider call runs, its output capped to what the hold covers.
 *   3. finish(): charge the actual cost — never more than the hold, so a
 *      balance can't go negative — release the rest, and close the log row.
 *
 * Amounts are integer micro-credits (1 credit = 1,000,000 micros). Prices are
 * credits per 1M tokens, so tokens × price is exactly micro-credits.
 */
const crypto = require('crypto');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { GatewayError } = require('./errors');

const MICROS_PER_CREDIT = 1_000_000;
// The smallest reply a hold must cover before a call is allowed at all.
const MIN_REPLY_TOKENS = 1024;
// Holds older than this belong to a crashed process and are released.
const STALE_HOLD_MINUTES = 15;

const toMicros = (credits) => Math.round(Number(credits) * MICROS_PER_CREDIT);
const toCredits = (micros) => Number(micros) / MICROS_PER_CREDIT;

// Conservative token estimate for holds: ~1 token per 3 UTF-8 bytes covers
// English (~4 chars/token) with room to spare and CJK (~1 token per char).
function estimateTokens(text) {
  return Math.ceil(Buffer.byteLength(text || '', 'utf8') / 3);
}
function estimateInputTokens(messages) {
  return messages.reduce((sum, m) => sum + estimateTokens(m.content) + 10, 10);
}
// For charging when a provider reports no usage (e.g. a stopped stream):
// closer to typical, so users aren't overcharged for an estimate.
function estimateOutputTokens(text) {
  return Math.ceil(Buffer.byteLength(text || '', 'utf8') / 4);
}

function rates(model) {
  return {
    inCredits: Number(model.input_credits_per_mtok),
    outCredits: Number(model.output_credits_per_mtok),
    inUsd: Number(model.input_cost_per_mtok || 0),
    outUsd: Number(model.output_cost_per_mtok || 0),
  };
}
function priceMicros(r, inputTokens, outputTokens) {
  return Math.ceil(inputTokens * r.inCredits + outputTokens * r.outCredits);
}
function costUsdMicros(r, inputTokens, outputTokens) {
  return Math.ceil(inputTokens * r.inUsd + outputTokens * r.outUsd);
}

/** Creates the user's account on first use, with the configured trial credits. */
async function ensureAccount(userId, { transaction } = {}) {
  const inserted = await sequelize.query(
    `INSERT INTO credit_accounts (user_id) VALUES (:userId)
     ON CONFLICT (user_id) DO NOTHING RETURNING user_id`,
    { replacements: { userId }, type: QueryTypes.SELECT, transaction }
  );
  const trial = toMicros(process.env.SIGNUP_TRIAL_CREDITS || 0);
  if (inserted.length && trial > 0) {
    await sequelize.query(
      `UPDATE credit_accounts SET balance_micros = :trial WHERE user_id = :userId;
       INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, reason)
       VALUES (:userId, 'grant', :trial, :trial, 'Trial credits')`,
      { replacements: { userId, trial }, transaction }
    );
  }
}

async function lockAccount(userId, transaction) {
  await ensureAccount(userId, { transaction });
  const [account] = await sequelize.query(
    'SELECT balance_micros, held_micros FROM credit_accounts WHERE user_id = :userId FOR UPDATE',
    { replacements: { userId }, type: QueryTypes.SELECT, transaction }
  );
  return { balance: Number(account.balance_micros), held: Number(account.held_micros) };
}

async function getBalance(userId) {
  await ensureAccount(userId);
  const [a] = await sequelize.query(
    'SELECT balance_micros, held_micros FROM credit_accounts WHERE user_id = :userId',
    { replacements: { userId }, type: QueryTypes.SELECT }
  );
  const balance = Number(a.balance_micros);
  const held = Number(a.held_micros);
  return { balance: toCredits(balance), held: toCredits(held), available: toCredits(balance - held) };
}

/**
 * Adds (or, for an adjustment, removes) credits. Refuses to take a balance
 * below what is currently held for in-flight replies.
 *
 * `externalRef` names the payment a grant came from (e.g. a Stripe invoice).
 * A second grant with the same ref changes nothing and returns
 * `duplicate: true`, so a retried webhook can't grant twice.
 */
async function addCredits(userId, credits, { type = 'grant', reason, createdBy = null, externalRef = null } = {}) {
  const amount = toMicros(credits);
  if (!Number.isFinite(amount) || amount === 0) {
    throw new GatewayError('INVALID_AMOUNT', 'Enter a non-zero amount of credits.', { status: 400 });
  }
  return sequelize.transaction(async (transaction) => {
    const account = await lockAccount(userId, transaction);
    if (externalRef) {
      const [existing] = await sequelize.query(
        'SELECT 1 FROM credit_transactions WHERE external_ref = :externalRef',
        { replacements: { externalRef }, type: QueryTypes.SELECT, transaction }
      );
      if (existing) return { balance: toCredits(account.balance), duplicate: true };
    }
    const after = account.balance + amount;
    if (after < account.held) {
      throw new GatewayError('INSUFFICIENT_CREDITS', 'That would take the balance below zero.', {
        status: 400,
      });
    }
    await sequelize.query(
      `UPDATE credit_accounts SET balance_micros = :after, updated_at = now() WHERE user_id = :userId;
       INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, reason, created_by, external_ref)
       VALUES (:userId, :type, :amount, :after, :reason, :createdBy, :externalRef)`,
      { replacements: { userId, after, amount, type, reason: reason || null, createdBy, externalRef }, transaction }
    );
    return { balance: toCredits(after), duplicate: false };
  });
}

/**
 * Reserves credits for one call and opens its request log. Returns a meter
 * whose `maxOutputTokens` is what the hold can pay for, and whose finish()
 * settles the call exactly once.
 */
async function start({ userId, chatId, model, route, upstreamModel, messages, maxOutputTokens }) {
  const r = rates(model);
  const inputEstimate = estimateInputTokens(messages);
  const minHold = priceMicros(r, inputEstimate, Math.min(MIN_REPLY_TOKENS, maxOutputTokens));
  const maxHold = priceMicros(r, inputEstimate, maxOutputTokens);
  const requestId = crypto.randomUUID();
  const startedAt = Date.now();

  const hold = await sequelize.transaction(async (transaction) => {
    const account = await lockAccount(userId, transaction);
    const available = account.balance - account.held;
    if (available < minHold) {
      throw new GatewayError(
        'INSUFFICIENT_CREDITS',
        `You don’t have enough credits for ${model.name}. ` +
          `It needs about ${toCredits(minHold).toFixed(2)}; you have ${toCredits(Math.max(available, 0)).toFixed(2)}.`,
        { status: 402 }
      );
    }
    const amount = Math.min(maxHold, available);
    await sequelize.query(
      `UPDATE credit_accounts SET held_micros = held_micros + :amount, updated_at = now() WHERE user_id = :userId;
       INSERT INTO request_logs (id, user_id, chat_id, model_id, route, upstream_model, held_micros)
       VALUES (:requestId, :userId, :chatId, :modelId, :route, :upstreamModel, :amount)`,
      {
        replacements: { amount, userId, requestId, chatId, modelId: model.id, route, upstreamModel },
        transaction,
      }
    );
    return amount;
  });

  // Whatever the hold covers beyond the input estimate goes to the reply.
  const affordableOutput = r.outCredits > 0
    ? Math.floor((hold - inputEstimate * r.inCredits) / r.outCredits)
    : maxOutputTokens;

  return {
    requestId,
    holdMicros: hold,
    maxOutputTokens: Math.max(1, Math.min(maxOutputTokens, affordableOutput)),
    /**
     * Settles the call. Pass the provider's token counts when it reported
     * them; otherwise `replyText` is used to estimate output (input falls
     * back to the hold estimate).
     */
    finish: ({ status, errorCode = null, inputTokens, outputTokens, replyText = '', firstTokenMs = null }) =>
      settle({
        requestId,
        userId,
        rates: r,
        status,
        errorCode,
        inputTokens,
        outputTokens,
        inputEstimate,
        replyText,
        firstTokenMs,
        durationMs: Date.now() - startedAt,
      }),
  };
}

async function settle({ requestId, userId, rates: r, status, errorCode, inputTokens, outputTokens, inputEstimate, replyText, firstTokenMs, durationMs }) {
  const haveUsage = Number.isFinite(inputTokens) && Number.isFinite(outputTokens);
  // A call that failed before producing anything costs nothing.
  const producedNothing = !haveUsage && !replyText;
  const input = haveUsage ? inputTokens : producedNothing ? 0 : inputEstimate;
  const output = haveUsage ? outputTokens : estimateOutputTokens(replyText);

  return sequelize.transaction(async (transaction) => {
    const [log] = await sequelize.query(
      "SELECT held_micros FROM request_logs WHERE id = :requestId AND status = 'in_progress' FOR UPDATE",
      { replacements: { requestId }, type: QueryTypes.SELECT, transaction }
    );
    if (!log) return null; // already settled

    const held = Number(log.held_micros);
    const price = priceMicros(r, input, output);
    const charged = Math.min(price, held);
    const account = await lockAccount(userId, transaction);
    const balanceAfter = account.balance - charged;

    await sequelize.query(
      `UPDATE credit_accounts
          SET held_micros = held_micros - :held, balance_micros = :balanceAfter, updated_at = now()
        WHERE user_id = :userId`,
      { replacements: { held, balanceAfter, userId }, transaction }
    );
    if (charged > 0) {
      await sequelize.query(
        `INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, request_id, reason)
         VALUES (:userId, 'charge', :amount, :balanceAfter, :requestId, 'Model usage')`,
        { replacements: { userId, amount: -charged, balanceAfter, requestId }, transaction }
      );
    }
    await sequelize.query(
      `UPDATE request_logs SET
         status = :status, error_code = :errorCode,
         input_tokens = :input, output_tokens = :output, usage_estimated = :estimated,
         charged_micros = :charged, unbilled_micros = :unbilled, cost_usd_micros = :cost,
         first_token_ms = :firstTokenMs, duration_ms = :durationMs, finished_at = now()
       WHERE id = :requestId`,
      {
        replacements: {
          requestId,
          status,
          errorCode,
          input,
          output,
          estimated: !haveUsage && !producedNothing,
          charged,
          unbilled: price - charged,
          cost: costUsdMicros(r, input, output),
          firstTokenMs,
          durationMs,
        },
        transaction,
      }
    );
    return {
      inputTokens: input,
      outputTokens: output,
      usageEstimated: !haveUsage && !producedNothing,
      charged: toCredits(charged),
      balance: toCredits(balanceAfter - (account.held - held)),
    };
  });
}

/**
 * Releases holds left by a process that died mid-call. Nothing is charged:
 * the reply never reached the user.
 */
async function releaseStaleHolds() {
  const stale = await sequelize.query(
    `SELECT id, user_id FROM request_logs
      WHERE status = 'in_progress' AND created_at < now() - (:minutes * interval '1 minute')`,
    { replacements: { minutes: STALE_HOLD_MINUTES }, type: QueryTypes.SELECT }
  );
  for (const row of stale) {
    await settle({
      requestId: row.id,
      userId: row.user_id,
      rates: { inCredits: 0, outCredits: 0, inUsd: 0, outUsd: 0 },
      status: 'failed',
      errorCode: 'STALE_HOLD_RELEASED',
      inputTokens: 0,
      outputTokens: 0,
      inputEstimate: 0,
      replyText: '',
      firstTokenMs: null,
      durationMs: null,
    });
  }
  if (stale.length) console.warn(`[metering] Released ${stale.length} stale credit hold(s)`);
  return stale.length;
}

module.exports = {
  start,
  getBalance,
  addCredits,
  ensureAccount,
  releaseStaleHolds,
  toCredits,
  toMicros,
  estimateInputTokens,
  MIN_REPLY_TOKENS,
};
