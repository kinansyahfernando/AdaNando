// src/utils/audit.js
// Catatan aktivitas penting (login, ubah data, reset ujian, dsb) untuk penelusuran.
const { pool } = require('../config/database');

const ipOf = (req) => (req && (req.ip || (req.connection && req.connection.remoteAddress))) || null;

async function audit(req, action, target = null, detail = null, actorId = null) {
  try {
    const actor = actorId != null ? actorId : req && req.user ? req.user.id : null;
    await pool.query(
      'INSERT INTO audit_logs (actor_id, action, target, detail, ip, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [actor, String(action).slice(0, 40), target == null ? null : String(target).slice(0, 80),
        detail == null ? null : String(detail).slice(0, 500), ipOf(req), Date.now()]
    );
  } catch (err) {
    console.error('⚠️ Gagal menulis audit log:', err.message);
  }
}

module.exports = { audit, ipOf };
