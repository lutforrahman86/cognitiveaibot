/**
 * Sends account emails (password reset, email verification, notices).
 *
 * With SMTP_URL set (e.g. smtps://user:pass@smtp.example.com:465 — any
 * provider's SMTP works), mail goes out through it from EMAIL_FROM. Without
 * it nothing is sent: in development each email is printed to the server log
 * so its links can be followed, and in tests it's kept in `outbox`.
 */
const nodemailer = require('nodemailer');

const outbox = [];
let transport = null;
let transportUrl = null;

function getTransport() {
  const url = process.env.SMTP_URL || null;
  if (url !== transportUrl) {
    transport = url ? nodemailer.createTransport(url) : null;
    transportUrl = url;
  }
  return transport;
}

const appName = () => process.env.APP_NAME || 'CognitiveAI Bot';
const frontendUrl = () => (process.env.FRONTEND_URL || 'http://localhost:5173').replace(/\/$/, '');

async function sendEmail({ to, subject, text }) {
  const mail = { from: process.env.EMAIL_FROM || `${appName()} <no-reply@localhost>`, to, subject, text };
  const smtp = getTransport();
  if (smtp) {
    await smtp.sendMail(mail);
    return;
  }
  if (process.env.NODE_ENV === 'test') {
    outbox.push(mail);
    return;
  }
  console.log(`[email] SMTP_URL isn't set, so this wasn't sent:\n  To: ${to}\n  Subject: ${subject}\n${text.replace(/^/gm, '  | ')}`);
}

const signOff = () => `\n\n— ${appName()}`;

const templates = {
  passwordReset: (token) => ({
    subject: `Reset your ${appName()} password`,
    text:
      `Someone asked to reset the password for this ${appName()} account. If it was you, set a new one here ` +
      `(the link works once, for the next hour):\n\n${frontendUrl()}/reset-password?token=${token}\n\n` +
      `If it wasn't you, ignore this email: your password hasn't changed.${signOff()}`,
  }),
  verifyEmail: (token) => ({
    subject: `Confirm your email for ${appName()}`,
    text:
      `Confirm this email address to finish setting up your ${appName()} account (the link works for 24 hours):\n\n` +
      `${frontendUrl()}/verify-email?token=${token}\n\nIf you didn't sign up, ignore this email.${signOff()}`,
  }),
  passwordChanged: () => ({
    subject: `Your ${appName()} password was changed`,
    text:
      `The password for your ${appName()} account was just changed, and every other device was signed out. ` +
      `If this wasn't you, reset your password straight away from the sign-in page and contact support.${signOff()}`,
  }),
  accountDeleted: () => ({
    subject: `Your ${appName()} account was deleted`,
    text:
      `Your ${appName()} account and its chats, settings and API keys have been deleted, and any web subscription ` +
      `was cancelled. A subscription bought in the App Store has to be cancelled in your Apple account settings. ` +
      `Billing records are kept as the law requires.${signOff()}`,
  }),
};

module.exports = { sendEmail, templates, outbox };
