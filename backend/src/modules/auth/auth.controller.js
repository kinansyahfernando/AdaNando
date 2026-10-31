const authService = require('./auth.service');

const login = async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ message: 'Email dan password wajib diisi' });
        }

        const data = await authService.login(email, password);
        res.status(200).json(data);
    } catch (error) {
        res.status(401).json({ message: error.message });
    }
};

const register = async (req, res) => {
    try {
        const { name, email, password, role } = req.body;
        
        if (!name || !email || !password) {
            return res.status(400).json({ message: 'Nama, email, dan password wajib diisi' });
        }

        const data = await authService.register(name, email, password, role);
        res.status(201).json(data);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
};

module.exports = { login, register };