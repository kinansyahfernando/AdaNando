// src/modules/tryout/tryout.controller.js
const service = require('./tryout.service');

const handle = (fn) => async (req, res) => {
  try {
    res.status(200).json(await fn(req));
  } catch (error) {
    if (!error.status) console.error('❌ Tryout error:', error);
    res.status(error.status || 500).json({ message: error.message || 'Terjadi kesalahan server' });
  }
};

const start = handle((req) => service.start(req.user));
const get = handle((req) => service.get(req.user, req.params.id));
const submitSection = handle((req) => service.submitSection(req.user, req.params.id, req.body));
const finish = handle((req) => service.finish(req.user, req.params.id, req.body));

module.exports = { start, get, submitSection, finish };
