const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

const METRIC_QUERIES = {
  weight: (userId, from, to) => prisma.weight.findMany({ where: { userId, date: { gte: from, lte: to } } }).then((r) => r.map((x) => x.kg)),
  sleepMinutes: (userId, from, to) => prisma.sleepEntry.findMany({ where: { userId, date: { gte: from, lte: to } } }).then((r) => r.map((x) => x.durationMinutes)),
  calories: (userId, from, to) => prisma.meal.findMany({ where: { userId, date: { gte: from, lte: to } } }).then((r) => r.map((x) => x.calories || 0)),
  spendPaise: (userId, from, to) => prisma.transaction.findMany({ where: { userId, date: { gte: from, lte: to } } }).then((r) => r.map((x) => x.amountPaise)),
};

// GET /analytics/compare?metric=weight&days=30
router.get('/', async (req, res) => {
  const { metric, days } = req.query;
  const windowDays = parseInt(days, 10) || 30;

  if (!METRIC_QUERIES[metric]) {
    return res.status(400).json({ error: `Unknown metric. Supported: ${Object.keys(METRIC_QUERIES).join(', ')}` });
  }

  const now = new Date();
  const currentFrom = new Date(now.getTime() - windowDays * 86400000);
  const previousFrom = new Date(now.getTime() - windowDays * 2 * 86400000);
  const previousTo = currentFrom;

  const [current, previous] = await Promise.all([
    METRIC_QUERIES[metric](req.userId, currentFrom, now),
    METRIC_QUERIES[metric](req.userId, previousFrom, previousTo),
  ]);

  if (current.length === 0 || previous.length === 0) {
    return res.json({ metric, windowDays, insufficientData: true, message: 'Not enough logged data in one or both periods.' });
  }

  const avg = (arr) => arr.reduce((a, b) => a + b, 0) / arr.length;
  const currentMean = avg(current);
  const previousMean = avg(previous);

  res.json({
    metric, windowDays,
    currentMean: +currentMean.toFixed(2),
    previousMean: +previousMean.toFixed(2),
    absoluteChange: +(currentMean - previousMean).toFixed(2),
    percentChange: previousMean !== 0 ? +(((currentMean - previousMean) / Math.abs(previousMean)) * 100).toFixed(1) : null,
    currentN: current.length,
    previousN: previous.length,
  });
});

module.exports = router;


