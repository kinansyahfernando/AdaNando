const express = require('express');
const env = require('../../config/env');
const { wrap } = require('../../utils/http');
const { authenticate } = require('../../middlewares/auth');
const { loginLimiter } = require('../../middlewares/limits');
const service = require('./auth.service');

const router = express.Router();

// Pengaturan publik yang dibutuhkan layar login
router.get('/config', (req, res) => {
  res.json({ allowRegister: env.allowRegister, appName: 'AdaNando' });
});

router.post("/login", loginLimiter, wrap(async (req, res) => {
  const { email, identifier, password } = req.body || {};
  res.json(await service.login(req, identifier || email, password));
}));

router.post("/register", loginLimiter, wrap(async (req, res) => {
  const { name, email, password } = req.body || {};
  res.status(201).json(await service.register(req, name, email, password));
}));

router.get('/me', authenticate, wrap(async (req, res) => res.json(await service.me(req.user))));

router.post('/change-password', authenticate, wrap(async (req, res) => {
  const { oldPassword, newPassword } = req.body || {};
  res.json(await service.changePassword(req, req.user, oldPassword, newPassword));
}));

router.post('/logout', authenticate, wrap(async (req, res) => res.json(await service.logout(req, req.user))));

module.exports = router;
