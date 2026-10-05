const UsageRecord = require('../../models/UsageRecord');
const UsageLimit = require('../../models/UsageLimit');
const AIModel = require('../../models/AIModel');

const DEMO_DAYS = [
  { day: 0, cost: 1.85, tokens: 380000, model_slugs: ['gpt-4o', 'claude-3-5-sonnet'] },
  { day: 1, cost: 2.10, tokens: 420000, model_slugs: ['gpt-4o', 'gemini-2-flash', 'gpt-4o-mini'] },
  { day: 2, cost: 1.95, tokens: 400000, model_slugs: ['claude-3-5-sonnet', 'gpt-4o'] },
  { day: 3, cost: 1.72, tokens: 350000, model_slugs: ['gemini-2-flash', 'perplexity-sonar'] },
  { day: 4, cost: 2.30, tokens: 470000, model_slugs: ['gpt-4o', 'claude-3-5-sonnet', 'gpt-4o-mini'] },
  { day: 5, cost: 1.55, tokens: 320000, model_slugs: ['gpt-4o-mini'] },
  { day: 6, cost: 0.98, tokens: 200000, model_slugs: ['perplexity-sonar'] },
];

async function seed(userId) {
  const models = await AIModel.findAll({});
  const modelBySlug = {};
  models.forEach((r) => (modelBySlug[r.slug] = r.id));

  const today = new Date();
  let totalCost = 0;

  for (const d of DEMO_DAYS) {
    const recordDate = new Date(today);
    recordDate.setDate(recordDate.getDate() - d.day);
    const dateStr = recordDate.toISOString().slice(0, 10);
    const costPerModel = (d.cost / d.model_slugs.length).toFixed(4);
    const tokensPerModel = Math.floor(d.tokens / d.model_slugs.length);

    for (const slug of d.model_slugs) {
      const modelId = modelBySlug[slug];
      if (!modelId) continue;
      await UsageRecord.upsert(userId, modelId, dateStr, {
        tokens_input: tokensPerModel,
        tokens_output: tokensPerModel,
        cost: parseFloat(costPerModel),
      });
    }
    totalCost += d.cost;
  }

  await UsageLimit.upsert(userId, { limit_amount: 16, limit_period: 'monthly' });
  console.log(`Seeded usage records (~$${totalCost.toFixed(2)}) and usage limit`);
}

module.exports = { seed };
