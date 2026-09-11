const express = require('express');
const plansRouter = require('./plans');
const sessionsRouter = require('./sessions');
const exerciseHistoryRouter = require('./exerciseHistory');
const summaryRouter = require('./summary');
const router = express.Router();


router.use('/plans', plansRouter);
router.use('/sessions', sessionsRouter);
router.use('/exercises', exerciseHistoryRouter);
router.use('/summary', summaryRouter);
module.exports = router;
