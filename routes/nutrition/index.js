const express = require('express');
const mealsRouter = require('./meals');
const waterRouter = require('./water');
const foodsRouter = require('./foods');
const summaryRouter = require('./summary');

const router = express.Router();

router.use('/meals', mealsRouter);
router.use('/water', waterRouter);
router.use('/foods', foodsRouter);
router.use('/summary', summaryRouter);

module.exports = router;