// src/modules/results/results.routes.js  ->  /api/v1/results
const express = require('express');
const { wrap } = require('../../utils/http');
const { authenticate, requirePasswordChanged } = require('../../middlewares/auth');
const service = require('./results.service');

const router = express.Router();
router.use(authenticate, requirePasswordChanged);

router.get('/history', wrap(async (req, res) => res.json(await service.history(req.user))));

module.exports = router;
