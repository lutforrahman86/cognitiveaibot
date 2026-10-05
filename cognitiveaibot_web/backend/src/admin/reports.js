/**
 * Content reports (roadmap E5): a user flags a model reply in one of their
 * own chats; admins review it in the Reports tab. The reply's text is copied
 * into the report, so it can still be reviewed if the chat is deleted.
 */
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { GatewayError } = require('../gateway/errors');

const REASONS = ['harmful', 'sexual', 'hateful', 'violent', 'illegal', 'inaccurate', 'other'];
const STATUSES = ['open', 'reviewed', 'actioned', 'dismissed'];
const invalid = (message) => new GatewayError('INVALID_REPORT', message, { status: 400 });

async function createReport(userId, { message_id: messageId, reason, details } = {}) {
  if (!REASONS.includes(reason)) throw invalid(`Choose a reason: ${REASONS.join(', ')}.`);
  if (!/^[0-9a-f-]{36}$/i.test(String(messageId))) throw invalid('Say which reply you’re reporting.');
  const [message] = await sequelize.query(
    `SELECT m.id, m.chat_id, m.content, a.name AS model_name FROM messages m
       JOIN chats c ON c.id = m.chat_id LEFT JOIN ai_models a ON a.id = m.model_id
      WHERE m.id = :messageId AND c.user_id = :userId AND m.role = 'assistant'`,
    { replacements: { messageId, userId }, type: QueryTypes.SELECT }
  );
  if (!message) throw new GatewayError('NOT_FOUND', 'That reply wasn’t found in your chats.', { status: 404 });
  const [report] = await sequelize.query(
    `INSERT INTO content_reports (reporter_id, message_id, chat_id, model_name, reason, details, content_excerpt)
     VALUES (:userId, :messageId, :chatId, :modelName, :reason, :details, :excerpt) RETURNING id, status, created_at`,
    {
      replacements: {
        userId,
        messageId,
        chatId: message.chat_id,
        modelName: message.model_name,
        reason,
        details: typeof details === 'string' ? details.trim().slice(0, 2000) || null : null,
        excerpt: message.content.slice(0, 4000),
      },
      type: QueryTypes.SELECT,
    }
  );
  return report;
}

async function listReports({ status = 'open', limit = 100 } = {}) {
  return sequelize.query(
    `SELECT r.*, u.email AS reporter_email, a.email AS reviewed_by_email
       FROM content_reports r LEFT JOIN users u ON u.id = r.reporter_id LEFT JOIN users a ON a.id = r.reviewed_by
      WHERE (CAST(:status AS text) = 'all' OR r.status = :status)
      ORDER BY r.created_at DESC LIMIT :limit`,
    { replacements: { status, limit }, type: QueryTypes.SELECT }
  );
}

async function updateReport(id, status, adminId) {
  if (!STATUSES.includes(status) || status === 'open') throw invalid('Status must be reviewed, actioned or dismissed.');
  if (!/^[0-9a-f-]{36}$/i.test(String(id))) return null;
  const [row] = await sequelize.query(
    `UPDATE content_reports SET status = :status, reviewed_by = :adminId, reviewed_at = now()
      WHERE id = :id RETURNING id, status`,
    { replacements: { id, status, adminId }, type: QueryTypes.SELECT }
  );
  return row || null;
}

module.exports = { createReport, listReports, updateReport, REASONS };
