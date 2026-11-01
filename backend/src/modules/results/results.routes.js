// src/modules/results/results.routes.js
const express = require('express');
const authMiddleware = require('../../middlewares/authMiddleware');
const controller = require('./results.controller');

const router = express.Router();
router.use(authMiddleware);

router.post('/', controller.savePractice); // simpan hasil latihan subtes
router.get('/history', controller.history); // riwayat untuk halaman Potensi

module.exports = router;
