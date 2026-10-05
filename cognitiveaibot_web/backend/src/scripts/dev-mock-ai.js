#!/usr/bin/env node
// Usage: npm run dev:mock-ai
//
// Runs the API exactly like `npm run dev`, except that OpenAI models are
// answered by a local mock provider instead of OpenAI. Replies are labelled
// as fake. For working on the chat UI without a provider key or any cost.
require('dotenv').config();
const { startMockProvider } = require('../../tests/mockProvider');

startMockProvider({ echo: true }).then((mock) => {
  process.env.OPENAI_BASE_URL = mock.baseUrl;
  process.env.OPENAI_API_KEY = 'mock-key';
  console.log(`Mock AI provider running at ${mock.baseUrl}: replies are NOT from a real model`);
  require('../index');
});
