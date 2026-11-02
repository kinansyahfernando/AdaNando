// src/utils/http.js
class HttpError extends Error {
  constructor(message, status = 400, extra = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

/** Bungkus handler async agar error otomatis diteruskan ke error handler Express. */
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

const toInt = (v, def = null) => {
  const n = Number(v);
  return Number.isInteger(n) ? n : def;
};

const clampInt = (v, min, max, def) => {
  const n = toInt(v, def);
  return Math.min(max, Math.max(min, n == null ? def : n));
};

const str = (v, max = 255) => (v == null ? '' : String(v).trim().slice(0, max));

const parseJson = (text, fallback) => {
  try {
    const v = JSON.parse(text);
    return v == null ? fallback : v;
  } catch (_) {
    return fallback;
  }
};

module.exports = { HttpError, wrap, toInt, clampInt, str, parseJson };
