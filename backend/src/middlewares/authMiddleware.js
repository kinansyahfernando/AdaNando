// src/middlewares/authMiddleware.js
// Memeriksa token JWT di header "Authorization: Bearer <token>".
// Kalau valid, data user disimpan di req.user = { id, email, role }.
const jwt = require('jsonwebtoken');

function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ message: 'Token tidak ditemukan. Silakan login ulang.' });
  }
  if (!process.env.JWT_SECRET) {
    return res.status(500).json({ message: 'JWT_SECRET belum diisi di file .env backend' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: payload.id, email: payload.email, role: payload.role };
    return next();
  } catch (err) {
    return res.status(401).json({ message: 'Sesi berakhir. Silakan login ulang.' });
  }
}

module.exports = authMiddleware;
module.exports.authMiddleware = authMiddleware;
