require('dotenv').config();
const express = require('express');
const logger = require('./lib/logger');
const requestLogger = require('./middleware/requestLogger');
const authRouter = require('./routes/auth');
const usersRouter = require('./routes/users');
const adminRouter = require('./routes/admin');
const healthRouter = require('./routes/health');
const fitnessRouter = require('./routes/fitness');



const app = express();

app.use(express.json());
app.use(requestLogger); 

app.use('/auth', authRouter);
app.use('/users', usersRouter);
app.use('/admin', adminRouter);
app.use('/health', healthRouter);
app.use('/fitness', fitnessRouter);

app.use((err, req, res, next) => {
  logger.error('Unhandled error', {
    requestId: req.requestId,
    method: req.method,
    path: req.originalUrl,
    message: err.message,
    stack: err.stack,
  });
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => logger.info(`Server running on port ${PORT}`));