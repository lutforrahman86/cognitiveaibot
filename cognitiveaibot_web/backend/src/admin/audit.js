/**
 * The admin audit log (roadmap E2): every change an admin makes, who made
 * it, and to what. Written in the same transaction as the change when one
 * is given, so a change is never recorded without happening or vice versa.
 */
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');

async function logAdminAction(adminId, action, { targetType, targetId = null, details = {} }, { transaction } = {}) {
  await sequelize.query(
    `INSERT INTO admin_actions (admin_id, action, target_type, target_id, details)
     VALUES (:adminId, :action, :targetType, :targetId, CAST(:details AS jsonb))`,
    {
      replacements: { adminId, action, targetType, targetId: targetId == null ? null : String(targetId), details: JSON.stringify(details) },
      transaction,
    }
  );
}

async function listAdminActions({ limit = 100, targetType, targetId } = {}) {
  return sequelize.query(
    `SELECT a.id, a.action, a.target_type, a.target_id, a.details, a.created_at, u.email AS admin_email
       FROM admin_actions a LEFT JOIN users u ON u.id = a.admin_id
      WHERE (CAST(:targetType AS text) IS NULL OR a.target_type = :targetType)
        AND (CAST(:targetId AS text) IS NULL OR a.target_id = :targetId)
      ORDER BY a.created_at DESC LIMIT :limit`,
    { replacements: { limit, targetType: targetType || null, targetId: targetId || null }, type: QueryTypes.SELECT }
  );
}

module.exports = { logAdminAction, listAdminActions };
