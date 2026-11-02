// src/modules/rooms/rooms.routes.js  ->  /api/v1/rooms  (Belajar Bareng)
const express = require('express');
const { wrap } = require('../../utils/http');
const { authenticate, requirePasswordChanged } = require('../../middlewares/auth');
const svc = require('./rooms.service');

const router = express.Router();
router.use(authenticate, requirePasswordChanged);

router.post('/', wrap(async (req, res) => res.json(await svc.createRoom(req.user, req.body))));
router.post('/join', wrap(async (req, res) => res.json(await svc.joinRoom(req.user, (req.body || {}).code))));
router.get('/:code', wrap(async (req, res) => res.json(await svc.getRoom(req.user, req.params.code))));
router.get('/:code/questions', wrap(async (req, res) => res.json(await svc.roomQuestions(req.user, req.params.code))));
router.get('/:code/review', wrap(async (req, res) => res.json(await svc.roomReview(req.user, req.params.code))));
router.post('/:code/start', wrap(async (req, res) => res.json(await svc.startRoom(req.user, req.params.code))));
router.post('/:code/submit', wrap(async (req, res) => res.json(await svc.submitAnswers(req.user, req.params.code, req.body))));
router.post('/:code/leave', wrap(async (req, res) => res.json(await svc.leaveRoom(req.user, req.params.code))));

module.exports = router;
