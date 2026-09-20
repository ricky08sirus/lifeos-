const express = require('express');
const insightsRouter = require('./insights');
const compareRouter = require('./compare');
const chartsRouter = require('./charts');

const router = express.Router();

router.use('/insights', insightsRouter);
router.use('/compare', compareRouter);
router.use('/charts', chartsRouter);

module.exports = router;

