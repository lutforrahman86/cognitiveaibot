/**
 * Model admin (roadmap A2, E1): switch models on and off, set their prices,
 * tier, lifecycle status and capabilities, and point them at a direct
 * provider route. Every change is checked here and audit-logged by the caller.
 */
const AIModel = require('../models/AIModel');
const { GatewayError } = require('../gateway/errors');

const invalid = (message) => new GatewayError('INVALID_MODEL', message, { status: 400 });
const MODALITIES = ['text', 'image', 'audio', 'video', 'embedding'];

const FIELDS = {
  name: (v) => {
    if (typeof v !== 'string' || !v.trim() || v.length > 100) throw invalid('The name must be 1–100 characters.');
    return v.trim();
  },
  category: (v) => (v == null || v === '' ? null : String(v).slice(0, 50)),
  is_active: (v) => Boolean(v),
  status: (v) => {
    if (!['beta', 'active', 'deprecated'].includes(v)) throw invalid('Status must be beta, active or deprecated.');
    return v;
  },
  tier: (v) => {
    if (!Number.isInteger(v) || v < 0 || v > 9) throw invalid('The tier must be a whole number from 0 (everyone) to 9.');
    return v;
  },
  // Direct providers only (Decision 1): a model's route is its own maker. A
  // provider without an integration yet is allowed; its models just can't be
  // called until one exists.
  provider: (v) => {
    if (typeof v !== 'string' || !v.trim()) throw invalid('Choose a provider.');
    return v.trim();
  },
  provider_model_id: (v) => (v == null || v === '' ? null : String(v).trim().slice(0, 150)),
  context_window: (v) => positiveIntOrNull(v, 'The context window'),
  max_output_tokens: (v) => positiveIntOrNull(v, 'The output limit'),
  input_cost_per_mtok: (v) => priceOrNull(v, 'The input cost'),
  output_cost_per_mtok: (v) => priceOrNull(v, 'The output cost'),
  input_credits_per_mtok: (v) => priceOrNull(v, 'The input price'),
  output_credits_per_mtok: (v) => priceOrNull(v, 'The output price'),
  unit_cost_usd: (v) => priceOrNull(v, 'The cost per unit', 6),
  unit_credits: (v) => priceOrNull(v, 'The price per unit', 6),
  supports_streaming: (v) => Boolean(v),
  supports_vision: (v) => Boolean(v),
  supports_tools: (v) => Boolean(v),
  supports_json: (v) => Boolean(v),
  input_modalities: (v) => modalities(v, 'Input'),
  output_modalities: (v) => modalities(v, 'Output'),
  display_order: (v) => {
    if (!Number.isInteger(v)) throw invalid('The display order must be a whole number.');
    return v;
  },
};

function positiveIntOrNull(v, label) {
  if (v == null || v === '') return null;
  if (!Number.isInteger(v) || v <= 0) throw invalid(`${label} must be a positive whole number.`);
  return v;
}
function priceOrNull(v, label, decimals = 4) {
  if (v == null || v === '') return null;
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0 || n > 1e8) throw invalid(`${label} must be a number of at least 0.`);
  const scale = 10 ** decimals;
  return Math.round(n * scale) / scale;
}
function modalities(v, label) {
  if (!Array.isArray(v) || !v.length || v.some((m) => !MODALITIES.includes(m))) {
    throw invalid(`${label} modalities must be a list of: ${MODALITIES.join(', ')}.`);
  }
  return [...new Set(v)];
}

/** Applies an admin's edit. Returns { before, after } with only the changed fields, or null if no such model. */
async function updateModel(id, body = {}) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id))) return null;
  const unknown = Object.keys(body).filter((k) => !(k in FIELDS));
  if (unknown.length) throw invalid(`These fields can't be edited: ${unknown.join(', ')}.`);
  const model = await AIModel.findByPk(id);
  if (!model) return null;

  const changes = {};
  for (const [field, value] of Object.entries(body)) changes[field] = FIELDS[field](value);
  const before = {};
  const after = {};
  for (const [field, value] of Object.entries(changes)) {
    const old = model.get(field);
    const same = JSON.stringify(old == null ? null : typeof old === 'object' ? old : String(old)) ===
      JSON.stringify(value == null ? null : typeof value === 'object' ? value : String(value));
    if (!same) {
      before[field] = old;
      after[field] = value;
    }
  }
  if (Object.keys(after).length) await model.update(after);
  return { model: model.get({ plain: true }), before, after };
}

module.exports = { updateModel };
