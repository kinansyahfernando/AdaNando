// src/modules/tryout/tryout.routes.js
const express = require('express');
const authMiddleware = require('../../middlewares/authMiddleware');
const controller = require('./tryout.controller');

const router = express.Router();
router.use(authMiddleware);

router.post('/start', controller.start); // mulai try out baru
router.get('/:id', controller.get); // sinkron waktu & status
router.post('/:id/submit-section', controller.submitSection); // kumpulkan 1 subtes
router.post('/:id/finish', controller.finish); // akhiri lebih awal

module.exports = router;
