// src/modules/rooms/rooms.controller.js
const roomsService = require('./rooms.service');

// Membungkus handler supaya error dikirim sebagai { message } dengan status yang benar
const handle = (fn) => async (req, res) => {
  try {
    const data = await fn(req);
    res.status(200).json(data);
  } catch (error) {
    if (!error.status) console.error('❌ Rooms error:', error);
    res.status(error.status || 500).json({ message: error.message || 'Terjadi kesalahan server' });
  }
};

const create = handle((req) => roomsService.createRoom(req.user, req.body));
const join = handle((req) => roomsService.joinRoom(req.user, (req.body || {}).code));
const get = handle((req) => roomsService.getRoom(req.user, req.params.code));
const start = handle((req) => roomsService.startRoom(req.user, req.params.code));
const submit = handle((req) => roomsService.submitAnswers(req.user, req.params.code, req.body));
const leave = handle((req) => roomsService.leaveRoom(req.user, req.params.code));

module.exports = { create, join, get, start, submit, leave };
