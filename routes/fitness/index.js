const express = require('express');
const plansRouter = require('./plans');
const sessionsRouter = require('./sessions');

const router = express.Router();

router.use('/plans', plansRouter);
router.use('/sessions', sessionsRouter);

module.exports = router;
