const authService = require('./auth.service');

const login = async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const data = await authService.login(email, password);
    res.status(200).json(data);
  } catch (error) {
    if (!error.status) console.error('❌ Login error:', error);
    res.status(error.status || 500).json({ message: error.message });
  }
};

const register = async (req, res) => {
  try {
    const { name, email, password } = req.body || {};

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Nama, email, dan password wajib diisi' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password minimal 6 karakter' });
    }

    // role dari client sengaja diabaikan
    const data = await authService.register(name, email, password);
    res.status(201).json(data);
  } catch (error) {
    if (!error.status) console.error('❌ Register error:', error);
    res.status(error.status || 500).json({ message: error.message });
  }
};

module.exports = { login, register };