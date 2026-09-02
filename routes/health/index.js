const express = require('express');
const weightsRouter = require('./weights');
const measurementsRouter = require('./measurements');
const sleepRouter = require('./sleep');
const wellbeingRouter = require('./wellbeing');
const vitalsRouter = require('./vitals');

const router = express.Router();

router.use('/weights', weightsRouter);
router.use('/measurements', measurementsRouter);
router.use('/sleep', sleepRouter);
router.use('/wellbeing', wellbeingRouter);
router.use('/vitals', vitalsRouter);

module.exports = router;