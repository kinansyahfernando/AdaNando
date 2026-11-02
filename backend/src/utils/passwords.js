// src/utils/passwords.js
const crypto = require('crypto');

// Tanpa karakter yang mirip (0/O, 1/l/I) supaya mudah dibaca saat dicetak di kartu login
const LETTERS = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
const DIGITS = '23456789';

const pick = (chars) => chars[crypto.randomInt(0, chars.length)];

/** Password acak 8 karakter: pasti ada huruf & angka. */
function generatePassword(length = 8) {
  const all = LETTERS + DIGITS;
  const chars = [pick(LETTERS), pick(DIGITS)];
  while (chars.length < length) chars.push(pick(all));
  for (let i = chars.length - 1; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}

module.exports = { generatePassword };
