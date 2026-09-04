const express = require('express');
const weightsRouter = require('./weights');
const measurementsRouter = require('./measurements');
const sleepRouter = require('./sleep');
const wellbeingRouter = require('./wellbeing');
const vitalsRouter = require('./vitals');
const medicationsRouter = require('./medications');
const appointmentsRouter = require('./appointments');
const photosRouter = require('./photos');
const recordsRouter = require('./records');
const summaryRouter = require('./summary');

const router = express.Router();

router.use('/weights', weightsRouter);
router.use('/measurements', measurementsRouter);
router.use('/sleep', sleepRouter);
router.use('/wellbeing', wellbeingRouter);
router.use('/vitals', vitalsRouter);
router.use('/medications', medicationsRouter);
router.use('/appointments', appointmentsRouter);
router.use('/photos', photosRouter);
router.use('/records', recordsRouter);
router.use('/summary', summaryRouter);

module.exports = router;