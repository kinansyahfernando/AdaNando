// src/modules/rooms/rooms.routes.js
const express = require('express');
const authMiddleware = require('../../middlewares/authMiddleware');
const roomsController = require('./rooms.controller');

const router = express.Router();

// Semua endpoint room wajib login
router.use(authMiddleware);

router.post('/', roomsController.create); // buat room
router.post('/join', roomsController.join); // gabung pakai kode (harus di atas '/:code')
router.get('/:code', roomsController.get); // status room (dipolling klien)
router.post('/:code/start', roomsController.start); // host mulai
router.post('/:code/submit', roomsController.submit); // kumpulkan jawaban
router.post('/:code/leave', roomsController.leave); // keluar dari room

module.exports = router;
