const express = require('express');
const cors = require('cors');
const authRoutes = require('./modules/auth/auth.routes');

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/v1/auth', authRoutes);

app.use((req, res) => {
    res.status(404).json({ message: 'Endpoint tidak ditemukan' });
});

module.exports = app;