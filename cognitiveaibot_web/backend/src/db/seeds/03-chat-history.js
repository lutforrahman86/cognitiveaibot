const Chat = require('../../models/Chat');
const Message = require('../../models/Message');
const AIModel = require('../../models/AIModel');

const CHAT_HISTORY = [
  { title: 'Explain quantum computing', excerpt: 'Can you explain how quantum computing works in simple terms?', category: 'Reasoning', model_slug: 'gpt-4o', messages: [{ role: 'user', content: 'Can you explain how quantum computing works in simple terms?' }, { role: 'assistant', content: 'Quantum computing uses quantum mechanics principles like superposition and entanglement. Instead of bits (0 or 1), qubits can exist in multiple states at once, allowing quantum computers to process many possibilities simultaneously and solve certain problems much faster than classical computers.' }] },
  { title: 'Python async/await tutorial', excerpt: 'How do I use async/await in Python?', category: 'Coding', model_slug: 'claude-3-5-sonnet', messages: [{ role: 'user', content: 'How do I use async/await in Python?' }, { role: 'assistant', content: 'In Python, use `async def` to define coroutines and `await` to call them. Example:\n\n```python\nimport asyncio\n\nasync def fetch_data():\n    await asyncio.sleep(1)\n    return "data"\n\nasync def main():\n    result = await fetch_data()\n    print(result)\n\nasyncio.run(main())\n```\n\nUse `asyncio.gather()` to run multiple coroutines concurrently.' }] },
  { title: 'Best practices for React hooks', excerpt: 'What are the best practices when using React hooks?', category: 'Coding', model_slug: 'gpt-4o-mini', messages: [{ role: 'user', content: 'What are the best practices when using React hooks?' }, { role: 'assistant', content: 'Key practices: 1) Only call hooks at the top level (not in loops/conditions). 2) Use custom hooks to extract logic. 3) Include all dependencies in useEffect. 4) Use useMemo/useCallback sparingly for expensive computations. 5) Prefer multiple focused hooks over one complex hook.' }] },
  { title: 'Recent AI research papers', excerpt: 'What are some notable AI research papers from 2024?', category: 'Search', model_slug: 'gemini-2-flash', messages: [{ role: 'user', content: 'What are some notable AI research papers from 2024?' }, { role: 'assistant', content: 'Notable 2024 papers include: GPT-5 architecture updates, Claude 3 model cards, Gemini multimodal capabilities, and advances in open-source models like Llama 3 and Mistral. Key focus areas: reasoning, long context, and multimodal understanding.' }] },
  { title: 'Debugging TypeScript errors', excerpt: 'How do I fix "Object is possibly undefined" in TypeScript?', category: 'Coding', model_slug: 'claude-3-haiku', messages: [{ role: 'user', content: 'How do I fix "Object is possibly undefined" in TypeScript?' }, { role: 'assistant', content: 'Use optional chaining (`?.`), nullish coalescing (`??`), or type guards. Example: `const value = obj?.prop ?? defaultValue`. For arrays: `arr?.[0]`. Use the non-null assertion (`!`) only when you\'re certain, e.g. `el!.focus()`.' }] },
  { title: 'Philosophy of consciousness', excerpt: 'What is the hard problem of consciousness?', category: 'Reasoning', model_slug: 'gpt-4-turbo', messages: [{ role: 'user', content: 'What is the hard problem of consciousness?' }, { role: 'assistant', content: 'The hard problem, posed by David Chalmers, is explaining why subjective experience exists at all—why there is something it feels like to be us. Physical processes can be explained, but why they give rise to felt experience remains a mystery. It contrasts with "easy" problems like memory or attention.' }] },
  { title: 'SQL vs NoSQL comparison', excerpt: 'When should I use SQL vs NoSQL?', category: 'Coding', model_slug: 'gemini-1-5-pro', messages: [{ role: 'user', content: 'When should I use SQL vs NoSQL?' }, { role: 'assistant', content: 'Use SQL (PostgreSQL, MySQL) when: you need ACID transactions, complex joins, relational data, strong consistency. Use NoSQL (MongoDB, DynamoDB) when: schema flexibility, horizontal scaling, document/key-value fits your model, eventual consistency is acceptable. Many apps use both.' }] },
  { title: 'Search optimization tips', excerpt: 'How to improve search relevance in my app?', category: 'Search', model_slug: 'perplexity-sonar', messages: [{ role: 'user', content: 'How to improve search relevance in my app?' }, { role: 'assistant', content: 'Consider: 1) Full-text search with stemming/ranking (PostgreSQL ts_rank, Elasticsearch). 2) Embeddings + vector search for semantic similarity. 3) Query expansion and synonyms. 4) User feedback loops. 5) A/B test relevance metrics. 6) Hybrid keyword + semantic approaches.' }] },
];

async function seed(userId) {
  // Only seed an empty history: re-running the seed used to add a full copy
  // of these chats every time.
  if (await Chat.count({ where: { user_id: userId } })) {
    console.log('Demo user already has chats, skipping chat history');
    return;
  }
  const models = await AIModel.findAll({});
  const modelSlugToId = {};
  models.forEach((r) => (modelSlugToId[r.slug] = r.id));

  for (const chat of CHAT_HISTORY) {
    const modelId = modelSlugToId[chat.model_slug] || null;
    const c = await Chat.create(userId, { title: chat.title, excerpt: chat.excerpt, model_id: modelId, category: chat.category });

    for (let i = 0; i < chat.messages.length; i++) {
      const msg = chat.messages[i];
      await Message.create(c.id, {
        role: msg.role,
        content: msg.content,
        model_id: msg.role === 'assistant' ? modelId : null,
        tokens_input: Math.floor(msg.content.length / 4),
        tokens_output: msg.role === 'assistant' ? Math.floor(msg.content.length / 4) : 0,
      }, userId);
    }
  }
  console.log(`Seeded ${CHAT_HISTORY.length} chats with messages`);
}

module.exports = { seed, CHAT_HISTORY };
