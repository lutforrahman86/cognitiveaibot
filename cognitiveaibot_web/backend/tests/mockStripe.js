/**
 * A local stand-in for the parts of Stripe's API the app calls, so billing
 * tests need no Stripe account. Point the SDK at it with STRIPE_API_BASE.
 * Every request is recorded with its form-encoded body flattened to
 * { 'line_items[0][price_data][unit_amount]': '1000', ... }.
 */
const http = require('http');

async function startMockStripe() {
  let counter = 0;
  const state = { requests: [] };
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
      if (req.method === 'POST' && req.url === '/v1/checkout/sessions') {
        const id = `cs_test_${counter}`;
        return json(200, { id, object: 'checkout.session', url: `https://checkout.stripe.test/${id}` });
      }
      if (req.method === 'POST' && req.url === '/v1/billing_portal/sessions') {
        return json(200, { id: `bps_${counter}`, object: 'billing_portal.session', url: 'https://billing.stripe.test/p' });
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
