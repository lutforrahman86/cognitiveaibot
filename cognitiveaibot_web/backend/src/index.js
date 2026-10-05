require('dotenv').config();
const { app } = require('./app');
const { initDatabase } = require('./db/init');
const { releaseStaleHolds, expireSubscriptionCredits } = require('./gateway/metering');
const mediaJobs = require('./gateway/mediaJobs');
const { checkSpendSpikes } = require('./admin/alerts');

const PORT = process.env.PORT || 3000;
const LEDGER_SWEEP_MS = 5 * 60 * 1000;

// Credit holds left by a process that died mid-reply would otherwise lock
// those credits forever, and subscription credits must lapse when their
// period ends without a renewal.
function sweepLedger() {
  releaseStaleHolds().catch((err) => console.error('Releasing stale credit holds failed:', err.message));
  expireSubscriptionCredits().catch((err) => console.error('Expiring subscription credits failed:', err.message));
  mediaJobs.deleteExpired().catch((err) => console.error('Deleting expired media failed:', err.message));
  checkSpendSpikes().catch((err) => console.error('Checking spending spikes failed:', err.message));
}

// Start server
async function start() {
  try {
    await initDatabase();
    sweepLedger();
    setInterval(sweepLedger, LEDGER_SWEEP_MS).unref();
    mediaJobs.startRunner();
    app.listen(PORT, () => {
      console.log(`Server running on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start server:', err.message);
    if (!process.env.DATABASE_URL) {
      console.error(
        'Tip: Create a .env file with DATABASE_URL and JWT_SECRET. See .env.example'
      );
    }
    process.exit(1);
  }
}

start();
