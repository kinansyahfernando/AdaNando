// src/modules/results/results.controller.js
const service = require('./results.service');

const handle = (fn) => async (req, res) => {
  try {
    res.status(200).json(await fn(req));
  } catch (error) {
    if (!error.status) console.error('❌ Results error:', error);
    res.status(error.status || 500).json({ message: error.message || 'Terjadi kesalahan server' });
  }
};

const savePractice = handle((req) => service.savePractice(req.user, req.body));
const history = handle((req) => service.history(req.user));

module.exports = { savePractice, history };
