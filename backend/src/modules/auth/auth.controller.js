const authService = require('./auth.service');

const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        
        if (!email || !password) {
            return res.status(400).json({ message: 'Email dan password wajib diisi' });
        }

        const data = await authService.login(email, password);
        
        res.status(200).json({
            message: 'Login berhasil',
            data: data
        });
    } catch (error) {
        res.status(401).json({ message: error.message });
    }
};

module.exports = { login };