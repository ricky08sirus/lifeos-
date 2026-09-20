require('dotenv').config();
const express = require('express');
const cors = require('cors'); 
const logger = require('./lib/logger');
const requestLogger = require('./middleware/requestLogger');
const authRouter = require('./routes/auth');
const usersRouter = require('./routes/users');
const adminRouter = require('./routes/admin');
const healthRouter = require('./routes/health');
const fitnessRouter = require('./routes/fitness');
const nutritionRouter = require('./routes/nutrition');
const habitsRouter = require('./routes/habits');
const financeRouter = require('./routes/finance');
const analyticsRouter = require('./routes/analytics');
const calendarRouter = require('./routes/calendar');
const documentsRouter = require('./routes/documents');
const reviewsRouter = require('./routes/reviews');
const searchRouter = require('./routes/search');

const app = express();
app.use(cors({
  origin: 'http://127.0.0.1:5500', 
  credentials: true                 
}));
// app.use(cors({ origin: 'http://127.0.0.1:5500' }));
//http://127.0.0.1:5500/
app.use(express.json());
app.use(requestLogger); 

app.use('/auth', authRouter);
app.use('/users', usersRouter);
app.use('/admin', adminRouter);
app.use('/health', healthRouter);
app.use('/fitness', fitnessRouter);
app.use('/nutrition', nutritionRouter);
app.use('/habits', habitsRouter);
app.use('/finance', financeRouter);
app.use('/analytics', analyticsRouter);
app.use('/calendar', calendarRouter);
app.use('/documents', documentsRouter);
app.use('/reviews', reviewsRouter);
app.use('/search', searchRouter);

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