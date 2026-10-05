require('dotenv').config();
const { app } = require('./app');
const { initDatabase } = require('./db/init');
const { releaseStaleHolds } = require('./gateway/metering');

const PORT = process.env.PORT || 3000;
const STALE_HOLD_SWEEP_MS = 5 * 60 * 1000;

// Credit holds left by a process that died mid-reply would otherwise lock
// those credits forever.
function sweepStaleHolds() {
  releaseStaleHolds().catch((err) => console.error('Releasing stale credit holds failed:', err.message));
}

// Start server
async function start() {
  try {
    await initDatabase();
    sweepStaleHolds();
    setInterval(sweepStaleHolds, STALE_HOLD_SWEEP_MS).unref();
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
