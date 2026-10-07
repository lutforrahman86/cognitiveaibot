/**
 * A local stand-in for the parts of Stripe's API the app calls, so billing
 * tests need no Stripe account. Point the SDK at it with STRIPE_API_BASE.
 * Every request is recorded with its form-encoded body flattened to
 * { 'line_items[0][price_data][unit_amount]': '1000', ... }.
 */
const http = require('http');

async function startMockStripe() {
  let counter = 0;
  const state = { requests: [], fixtures: { sessions: [], invoicePayments: [], paymentIntents: [], invoices: [] } };
  const server = http.createServer((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      const body = Object.fromEntries(new URLSearchParams(raw));
      state.requests.push({ method: req.method, path: req.url, body, headers: req.headers });
      counter += 1;
      const json = (status, payload) => {
        res.writeHead(status, { 'Content-Type': 'application/json', 'Request-Id': `req_${counter}` });
        res.end(JSON.stringify(payload));
      };
      if (req.method === 'POST' && req.url === '/v1/customers') {
        return json(200, { id: `cus_test_${counter}`, object: 'customer', email: body.email });
      }
      const deleted = req.url.match(/^\/v1\/customers\/([^/?]+)$/);
      if (req.method === 'DELETE' && deleted) {
        return json(200, { id: deleted[1], object: 'customer', deleted: true });
      }
      if (req.method === 'POST' && req.url === '/v1/checkout/sessions') {
        const id = `cs_test_${counter}`;
        return json(200, { id, object: 'checkout.session', url: `https://checkout.stripe.test/${id}` });
      }
      if (req.method === 'POST' && req.url === '/v1/billing_portal/sessions') {
        return json(200, { id: `bps_${counter}`, object: 'billing_portal.session', url: 'https://billing.stripe.test/p' });
      }
      // Lookups, answered from `state.fixtures` (set by each test).
      const url = new URL(req.url, 'http://mock');
      const q = url.searchParams;
      const list = (data) => json(200, { object: 'list', data, has_more: false });
      const f = state.fixtures;
      if (req.method === 'GET' && url.pathname === '/v1/checkout/sessions') {
        return list(f.sessions.filter((x) => x.payment_intent === q.get('payment_intent')));
      }
      if (req.method === 'GET' && url.pathname === '/v1/invoice_payments') {
        return list(f.invoicePayments.filter((x) => x.payment_intent === q.get('payment[payment_intent]')));
      }
      if (req.method === 'GET' && url.pathname.startsWith('/v1/payment_intents/')) {
        const intent = f.paymentIntents.find((x) => x.id === url.pathname.split('/').pop());
        return intent ? json(200, intent) : json(404, { error: { type: 'invalid_request_error', message: 'No such payment_intent' } });
      }
      if (req.method === 'GET' && url.pathname === '/v1/invoices') {
        return list(f.invoices.filter((x) => x.customer === q.get('customer')));
      }
      json(404, { error: { type: 'invalid_request_error', message: `No mock for ${req.method} ${req.url}` } });
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return Object.assign(state, {
    baseUrl: `http://127.0.0.1:${server.address().port}`,
    calls: (path) => state.requests.filter((r) => r.path === path),
    close: () => new Promise((r) => server.close(r)),
  });
}

module.exports = { startMockStripe };
