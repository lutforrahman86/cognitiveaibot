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
 *
 * Part of a balance can be the current period's subscription credits
 * (`subscription_micros`), which expire at `subscription_expires_at`; the rest
 * (top-ups, admin grants) never expires. Charges spend subscription credits
 * first, since those would be lost anyway.
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
// Subscription credits outlive their period by this much. Stripe charges a
// renewal about an hour after the period ends; without the grace, a renewing
// subscriber would briefly lose their plan credits every period. A paid
// renewal replaces the old credits at once, grace or not.
const SUBSCRIPTION_GRACE_HOURS = 24;

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
    `SELECT balance_micros, held_micros, subscription_micros, subscription_expires_at
       FROM credit_accounts WHERE user_id = :userId FOR UPDATE`,
    { replacements: { userId }, type: QueryTypes.SELECT, transaction }
  );
  return {
    balance: Number(account.balance_micros),
    held: Number(account.held_micros),
    subscription: Number(account.subscription_micros),
    subscriptionExpiresAt: account.subscription_expires_at,
  };
}

async function getBalance(userId) {
  await ensureAccount(userId);
  const [a] = await sequelize.query(
    `SELECT balance_micros, held_micros, subscription_micros, subscription_expires_at
       FROM credit_accounts WHERE user_id = :userId`,
    { replacements: { userId }, type: QueryTypes.SELECT }
  );
  const balance = Number(a.balance_micros);
  const held = Number(a.held_micros);
  const subscription = Number(a.subscription_micros);
  return {
    balance: toCredits(balance),
    held: toCredits(held),
    available: toCredits(balance - held),
    // The part of the balance that lapses when the subscription period ends.
    expiring: subscription > 0 ? { credits: toCredits(subscription), at: a.subscription_expires_at } : null,
  };
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
      `UPDATE credit_accounts
          SET balance_micros = :after, subscription_micros = LEAST(subscription_micros, :after), updated_at = now()
        WHERE user_id = :userId;
       INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, reason, created_by, external_ref)
       VALUES (:userId, :type, :amount, :after, :reason, :createdBy, :externalRef)`,
      { replacements: { userId, after, amount, type, reason: reason || null, createdBy, externalRef }, transaction }
    );
    return { balance: toCredits(after), duplicate: false };
  });
}

/** Holds `amount` micros and opens the request log, in one transaction. */
async function openHold(transaction, { userId, requestId, chatId, model, route, upstreamModel, amount, source, apiKeyId }) {
  await sequelize.query(
    `UPDATE credit_accounts SET held_micros = held_micros + :amount, updated_at = now() WHERE user_id = :userId;
     INSERT INTO request_logs (id, user_id, chat_id, model_id, route, upstream_model, held_micros, source, api_key_id, unit)
     VALUES (:requestId, :userId, :chatId, :modelId, :route, :upstreamModel, :amount, :source, :apiKeyId, :unit)`,
    {
      replacements: {
        amount,
        userId,
        requestId,
        chatId,
        modelId: model.id ?? null,
        route,
        upstreamModel,
        source,
        apiKeyId,
        unit: model.pricing_unit && model.pricing_unit !== 'token' ? model.pricing_unit : null,
      },
      transaction,
    }
  );
}

const insufficient = (model, needed, available) =>
  new GatewayError(
    'INSUFFICIENT_CREDITS',
    `You don’t have enough credits for ${model.name}. ` +
      `It needs about ${toCredits(needed).toFixed(2)}; you have ${toCredits(Math.max(available, 0)).toFixed(2)}.`,
    { status: 402 }
  );

/**
 * Reserves credits for one token-billed call and opens its request log.
 * Returns a meter whose `maxOutputTokens` is what the hold can pay for, and
 * whose finish() settles the call exactly once.
 */
async function start({ userId, chatId = null, model, route, upstreamModel, messages, maxOutputTokens, source = 'app', apiKeyId = null }) {
  const r = rates(model);
  const inputEstimate = estimateInputTokens(messages);
  const minHold = priceMicros(r, inputEstimate, Math.min(MIN_REPLY_TOKENS, maxOutputTokens));
  const maxHold = priceMicros(r, inputEstimate, maxOutputTokens);
  const requestId = crypto.randomUUID();
  const startedAt = Date.now();

  const hold = await sequelize.transaction(async (transaction) => {
    const account = await lockAccount(userId, transaction);
    const available = account.balance - account.held;
    if (available < minHold) throw insufficient(model, minHold, available);
    const amount = Math.min(maxHold, available);
    await openHold(transaction, { userId, requestId, chatId, model, route, upstreamModel, amount, source, apiKeyId });
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
    finish: ({ status, errorCode = null, inputTokens, outputTokens, replyText = '', firstTokenMs = null }) => {
      const haveUsage = Number.isFinite(inputTokens) && Number.isFinite(outputTokens);
      // A call that failed before producing anything costs nothing.
      const producedNothing = !haveUsage && !replyText;
      const input = haveUsage ? inputTokens : producedNothing ? 0 : inputEstimate;
      const output = haveUsage ? outputTokens : estimateOutputTokens(replyText);
      return settleRequest(requestId, {
        status,
        errorCode,
        priceMicros: priceMicros(r, input, output),
        costUsdMicros: costUsdMicros(r, input, output),
        inputTokens: input,
        outputTokens: output,
        estimated: !haveUsage && !producedNothing,
        firstTokenMs,
        durationMs: Date.now() - startedAt,
      });
    },
  };
}

/** What `units` of a unit-billed model (characters or seconds) cost us and the user, in micros. */
function unitPrice(model, units) {
  if (model.pricing_unit === 'second') {
    return {
      priceMicros: Math.ceil(units * Number(model.unit_credits) * MICROS_PER_CREDIT),
      costUsdMicros: Math.ceil(units * Number(model.unit_cost_usd || 0) * 1e6),
    };
  }
  // Characters (and tokens) use the per-1M input price.
  const r = rates(model);
  return { priceMicros: priceMicros(r, units, 0), costUsdMicros: costUsdMicros(r, units, 0) };
}

/** What a token-billed media call costs (embeddings, images). */
function tokenPrice(model, inputTokens, outputTokens) {
  const r = rates(model);
  return { priceMicros: priceMicros(r, inputTokens, outputTokens), costUsdMicros: costUsdMicros(r, inputTokens, outputTokens) };
}

/**
 * Reserves exactly `holdMicros` for a media call whose worst case is known
 * up front (refused with 402 if the user can't cover it) and opens its
 * request log. finish() settles it; a long job can instead be settled later,
 * from anywhere, with settleRequest(requestId, ...).
 */
async function startFixed({ userId, chatId = null, model, route, upstreamModel, holdMicros, source = 'app', apiKeyId = null }) {
  const amount = Math.max(1, Math.ceil(holdMicros));
  const requestId = crypto.randomUUID();
  const startedAt = Date.now();
  await sequelize.transaction(async (transaction) => {
    const account = await lockAccount(userId, transaction);
    const available = account.balance - account.held;
    if (available < amount) throw insufficient(model, amount, available);
    await openHold(transaction, { userId, requestId, chatId, model, route, upstreamModel, amount, source, apiKeyId });
  });
  return {
    requestId,
    holdMicros: amount,
    finish: (outcome) => settleRequest(requestId, { durationMs: Date.now() - startedAt, ...outcome }),
  };
}

/**
 * Settles a call: charges `priceMicros` (never more than the hold; any
 * excess is logged as unbilled), releases the rest of the hold and closes
 * the request log. Settles at most once; returns null if already settled.
 */
async function settleRequest(requestId, {
  status, errorCode = null, priceMicros: price = 0, costUsdMicros: cost = 0,
  inputTokens = null, outputTokens = null, units = null, estimated = false, firstTokenMs = null, durationMs = null,
}) {
  return sequelize.transaction(async (transaction) => {
    const [log] = await sequelize.query(
      "SELECT user_id, held_micros FROM request_logs WHERE id = :requestId AND status = 'in_progress' FOR UPDATE",
      { replacements: { requestId }, type: QueryTypes.SELECT, transaction }
    );
    if (!log) return null; // already settled

    const userId = log.user_id;
    const held = Number(log.held_micros);
    const charged = Math.min(price, held);
    let balanceAfter = null;
    let heldAfter = 0;
    if (userId) {
      const account = await lockAccount(userId, transaction);
      balanceAfter = account.balance - charged;
      heldAfter = account.held - held;
      await sequelize.query(
        `UPDATE credit_accounts
            SET held_micros = held_micros - :held, balance_micros = :balanceAfter,
                subscription_micros = GREATEST(subscription_micros - :charged, 0), updated_at = now()
          WHERE user_id = :userId`,
        { replacements: { held, balanceAfter, charged, userId }, transaction }
      );
      if (charged > 0) {
        await sequelize.query(
          `INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, request_id, reason)
           VALUES (:userId, 'charge', :amount, :balanceAfter, :requestId, 'Model usage')`,
          { replacements: { userId, amount: -charged, balanceAfter, requestId }, transaction }
        );
      }
    }
    await sequelize.query(
      `UPDATE request_logs SET
         status = :status, error_code = :errorCode,
         input_tokens = :inputTokens, output_tokens = :outputTokens, units = :units, usage_estimated = :estimated,
         charged_micros = :charged, unbilled_micros = :unbilled, cost_usd_micros = :cost,
         first_token_ms = :firstTokenMs, duration_ms = :durationMs, finished_at = now()
       WHERE id = :requestId`,
      {
        replacements: {
          requestId,
          status,
          errorCode,
          inputTokens,
          outputTokens,
          units,
          estimated,
          charged,
          unbilled: price - charged,
          cost,
          firstTokenMs,
          durationMs,
        },
        transaction,
      }
    );
    return {
      inputTokens,
      outputTokens,
      units,
      usageEstimated: estimated,
      charged: toCredits(charged),
      balance: balanceAfter === null ? null : toCredits(balanceAfter - heldAfter),
    };
  });
}

/**
 * Removes whatever is left of the account's subscription credits, recording
 * it as an 'expiry'. Never takes the balance below what in-flight replies
 * hold; any remainder is retried by the next sweep. Returns micros expired.
 */
async function expireLeftover(userId, account, transaction, reason) {
  const amount = Math.min(account.subscription, account.balance - account.held);
  if (amount <= 0) return 0;
  const after = account.balance - amount;
  await sequelize.query(
    `UPDATE credit_accounts
        SET balance_micros = :after, subscription_micros = subscription_micros - :amount, updated_at = now()
      WHERE user_id = :userId;
     INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, reason)
     VALUES (:userId, 'expiry', :negative, :after, :reason)`,
    { replacements: { userId, after, amount, negative: -amount, reason }, transaction }
  );
  account.balance = after;
  account.subscription -= amount;
  return amount;
}

/**
 * Grants one paid subscription period's credits. They expire at
 * `periodEnd` (plus a grace period); anything left from the previous period
 * expires first, so unused plan credits never pile up. Idempotent by
 * `externalRef`, like addCredits.
 */
async function grantSubscriptionCredits(userId, credits, { periodEnd, reason, externalRef }) {
  const amount = toMicros(credits);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new GatewayError('INVALID_AMOUNT', 'Enter a positive amount of credits.', { status: 400 });
  }
  return sequelize.transaction(async (transaction) => {
    const account = await lockAccount(userId, transaction);
    const [existing] = await sequelize.query('SELECT 1 FROM credit_transactions WHERE external_ref = :externalRef', {
      replacements: { externalRef },
      type: QueryTypes.SELECT,
      transaction,
    });
    if (existing) return { balance: toCredits(account.balance), duplicate: true };

    await expireLeftover(userId, account, transaction, 'Unused plan credits from the previous period');
    const after = account.balance + amount;
    await sequelize.query(
      `UPDATE credit_accounts
          SET balance_micros = :after, subscription_micros = subscription_micros + :amount,
              subscription_expires_at = CAST(:periodEnd AS timestamptz) + (:graceHours * interval '1 hour'),
              updated_at = now()
        WHERE user_id = :userId;
       INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, reason, external_ref)
       VALUES (:userId, 'purchase', :amount, :after, :reason, :externalRef)`,
      {
        replacements: {
          userId,
          after,
          amount,
          periodEnd: new Date(periodEnd).toISOString(),
          graceHours: SUBSCRIPTION_GRACE_HOURS,
          reason,
          externalRef,
        },
        transaction,
      }
    );
    return { balance: toCredits(after), duplicate: false };
  });
}

/** Expires subscription credits whose period (and grace) has ended without a renewal. */
async function expireSubscriptionCredits() {
  const due = await sequelize.query(
    `SELECT user_id FROM credit_accounts
      WHERE subscription_micros > 0 AND subscription_expires_at <= now()`,
    { type: QueryTypes.SELECT }
  );
  let expired = 0;
  for (const { user_id: userId } of due) {
    await sequelize.transaction(async (transaction) => {
      const account = await lockAccount(userId, transaction);
      // Re-checked under the lock: a renewal may have just replaced them.
      if (account.subscription <= 0 || new Date(account.subscriptionExpiresAt) > new Date()) return;
      if (await expireLeftover(userId, account, transaction, 'Plan credits expired at the end of the period')) {
        expired += 1;
      }
    });
  }
  if (expired) console.log(`[metering] Expired subscription credits for ${expired} account(s)`);
  return expired;
}

/**
 * Refunds one call's charge in full (roadmap A5), e.g. for a bad reply.
 * At most once per call: checked here, and enforced by the ledger's unique
 * (request_id, type) index.
 */
async function refundCharge(requestId, { reason, createdBy = null }) {
  if (!/^[0-9a-f-]{36}$/i.test(String(requestId))) {
    throw new GatewayError('REQUEST_NOT_FOUND', 'No such request.', { status: 404 });
  }
  return sequelize.transaction(async (transaction) => {
    const [log] = await sequelize.query(
      'SELECT user_id, status, charged_micros FROM request_logs WHERE id = :requestId FOR UPDATE',
      { replacements: { requestId }, type: QueryTypes.SELECT, transaction }
    );
    if (!log) throw new GatewayError('REQUEST_NOT_FOUND', 'No such request.', { status: 404 });
    if (log.status === 'in_progress') {
      throw new GatewayError('REQUEST_IN_PROGRESS', 'This request is still running.', { status: 400 });
    }
    const amount = Number(log.charged_micros);
    if (!log.user_id || amount <= 0) {
      throw new GatewayError('NOTHING_TO_REFUND', 'Nothing was charged for this request.', { status: 400 });
    }
    const [done] = await sequelize.query(
      "SELECT 1 FROM credit_transactions WHERE request_id = :requestId AND type = 'refund'",
      { replacements: { requestId }, type: QueryTypes.SELECT, transaction }
    );
    if (done) throw new GatewayError('ALREADY_REFUNDED', 'This request was already refunded.', { status: 409 });

    const account = await lockAccount(log.user_id, transaction);
    const after = account.balance + amount;
    await sequelize.query(
      `UPDATE credit_accounts SET balance_micros = :after, updated_at = now() WHERE user_id = :userId;
       INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, request_id, reason, created_by)
       VALUES (:userId, 'refund', :amount, :after, :requestId, :reason, :createdBy)`,
      { replacements: { userId: log.user_id, after, amount, requestId, reason, createdBy }, transaction }
    );
    return { userId: log.user_id, refunded: toCredits(amount), balance: toCredits(after) };
  });
}

/**
 * Takes back credits a refunded payment granted: `fraction` of the grant
 * recorded under `grantRef` (1 for a full refund). Credits already spent
 * can't be taken back; that shortfall is recorded in the reason. Idempotent
 * by `refundRef`. Returns null when no grant has that ref.
 */
async function reverseGrant(grantRef, { refundRef, fraction = 1, reason }) {
  return sequelize.transaction(async (transaction) => {
    const [grant] = await sequelize.query(
      'SELECT user_id, amount_micros FROM credit_transactions WHERE external_ref = :grantRef',
      { replacements: { grantRef }, type: QueryTypes.SELECT, transaction }
    );
    if (!grant?.user_id) return null;
    const account = await lockAccount(grant.user_id, transaction);
    const [done] = await sequelize.query('SELECT 1 FROM credit_transactions WHERE external_ref = :refundRef', {
      replacements: { refundRef },
      type: QueryTypes.SELECT,
      transaction,
    });
    if (done) return { duplicate: true };

    const wanted = Math.round(Number(grant.amount_micros) * Math.min(Math.max(fraction, 0), 1));
    const taken = Math.max(0, Math.min(wanted, account.balance - account.held));
    const after = account.balance - taken;
    const shortfall = wanted - taken;
    const note = shortfall > 0 ? ` (${toCredits(shortfall)} credits were already used)` : '';
    await sequelize.query(
      `UPDATE credit_accounts
          SET balance_micros = :after, subscription_micros = LEAST(subscription_micros, :after), updated_at = now()
        WHERE user_id = :userId;
       INSERT INTO credit_transactions (user_id, type, amount_micros, balance_after_micros, reason, external_ref)
       VALUES (:userId, 'adjustment', :amount, :after, :reason, :refundRef)`,
      {
        replacements: { userId: grant.user_id, after, amount: -taken, reason: `${reason}${note}`, refundRef },
        transaction,
      }
    );
    return { userId: grant.user_id, removed: toCredits(taken), shortfall: toCredits(shortfall), duplicate: false };
  });
}

/**
 * Releases holds left by a process that died mid-call. Nothing is charged:
 * the reply never reached the user. Media jobs still running keep their
 * holds; the job runner settles those.
 */
async function releaseStaleHolds() {
  const stale = await sequelize.query(
    `SELECT r.id FROM request_logs r
      WHERE r.status = 'in_progress' AND r.created_at < now() - (:minutes * interval '1 minute')
        AND NOT EXISTS (SELECT 1 FROM media_jobs j WHERE j.request_id = r.id AND j.status IN ('queued', 'in_progress'))`,
    { replacements: { minutes: STALE_HOLD_MINUTES }, type: QueryTypes.SELECT }
  );
  for (const row of stale) {
    await settleRequest(row.id, { status: 'failed', errorCode: 'STALE_HOLD_RELEASED', inputTokens: 0, outputTokens: 0 });
  }
  if (stale.length) console.warn(`[metering] Released ${stale.length} stale credit hold(s)`);
  return stale.length;
}

module.exports = {
  start,
  startFixed,
  settleRequest,
  unitPrice,
  tokenPrice,
  getBalance,
  addCredits,
  grantSubscriptionCredits,
  expireSubscriptionCredits,
  refundCharge,
  reverseGrant,
  ensureAccount,
  releaseStaleHolds,
  toCredits,
  toMicros,
  estimateInputTokens,
  estimateTokens,
  MIN_REPLY_TOKENS,
};
