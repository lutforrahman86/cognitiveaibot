#!/usr/bin/env node
// Usage: npm run models:verify
//
// For every provider with a key configured, fetches its live model list and
// reports whether each of our models' provider_model_id still exists there.
// Model ids get retired regularly; run this after changing keys or seeds.
require('dotenv').config();
const { sequelize } = require('../config/database');
const AIModel = require('../models/AIModel');
const { getProvider } = require('../gateway/providers');

async function fetchModelIds(provider) {
  const res = await fetch(`${provider.baseUrl}/models`, {
    headers: { Authorization: `Bearer ${provider.apiKey}` },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} listing models`);
  const body = await res.json();
  return new Set((body.data || []).map((m) => String(m.id).replace(/^models\//, '')));
}

async function run() {
  const models = await AIModel.findAll({ includeInactive: true });
  const byProvider = new Map();
  for (const m of models) {
    if (!byProvider.has(m.provider)) byProvider.set(m.provider, []);
    byProvider.get(m.provider).push(m);
  }

  let problems = 0;
  for (const [name, list] of byProvider) {
    const provider = getProvider(name);
    if (!provider) {
      console.log(`${name}: no adapter yet (${list.length} model(s) listed but not callable)`);
      continue;
    }
    if (!provider.apiKey) {
      console.log(`${name}: no API key configured, skipped`);
      continue;
    }
    let live;
    try {
      live = await fetchModelIds(provider);
    } catch (err) {
      console.log(`${name}: could not list models: ${err.message}`);
      problems++;
      continue;
    }
    for (const m of list) {
      if (!m.provider_model_id) {
        console.log(`  ${name} ${m.slug}: no provider_model_id`);
      } else if (live.has(m.provider_model_id)) {
        console.log(`  ok       ${name} ${m.slug} → ${m.provider_model_id}`);
      } else {
        console.log(`  MISSING  ${name} ${m.slug} → ${m.provider_model_id} is not offered by ${name}`);
        problems++;
      }
    }
  }
  process.exitCode = problems ? 1 : 0;
}

run()
  .catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => sequelize.close());
