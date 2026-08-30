require('dotenv').config();
const express = require('express');
const authRouter = require('./routes/auth');
const usersRouter = require('./routes/users');

const app = express();

app.use(express.json());
app.use('/auth', authRouter);
app.use('/users', usersRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));