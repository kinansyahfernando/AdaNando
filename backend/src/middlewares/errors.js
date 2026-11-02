// src/middlewares/errors.js
const notFound = (req, res) => {
  res.status(404).json({ message: `Route ${req.method} ${req.originalUrl} tidak ditemukan` });
};

// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  if (err && err.type === 'entity.parse.failed') {
    return res.status(400).json({ message: 'Format data tidak valid.' });
  }
  if (err && err.type === 'entity.too.large') {
    return res.status(413).json({ message: 'Data terlalu besar.' });
  }
  const status = err.status || 500;
  if (status >= 500) console.error('❌ Error:', err.code || '', err.message, (err.stack || '').split('\n').slice(1, 3).join(' | '));
  // Pesan error teknis (SQL dsb) tidak dibocorkan ke pengguna
  const message = status >= 500 && !err.status ? 'Terjadi kesalahan pada server.' : err.message;
  res.status(status).json({ message, ...(err.extra || {}) });
};

module.exports = { notFound, errorHandler };
