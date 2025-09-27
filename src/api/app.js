// src/api/app.js
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const app = express();

app.use(cors());
app.use(helmet());
app.get('/', (req, res) => res.send('CyberCell API is running!'));

const PORT = process.env.API_PORT || 8000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));