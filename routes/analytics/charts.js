const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

const SERIES_QUERIES = {
  weight: (userId) => prisma.weight.findMany({ where: { userId }, orderBy: { date: 'asc' } }).then((r) => r.map((x) => ({ date: x.date, value: x.kg }))),
  sleepMinutes: (userId) => prisma.sleepEntry.findMany({ where: { userId }, orderBy: { date: 'asc' } }).then((r) => r.map((x) => ({ date: x.date, value: x.durationMinutes }))),
  restingHeartRate: (userId) => prisma.vital.findMany({ where: { userId, kind: 'resting_heart_rate' }, orderBy: { recordedAt: 'asc' } }).then((r) => r.map((x) => ({ date: x.recordedAt, value: x.value }))),
  calories: (userId) => prisma.meal.groupBy({ by: ['date'], where: { userId }, _sum: { calories: true }, orderBy: { date: 'asc' } }).then((r) => r.map((x) => ({ date: x.date, value: x._sum.calories || 0 }))),
};

// Simple outlier correction: drop points more than 3 std deviations from the mean
function removeOutliers(points) {
  if (points.length < 4) return points;
  const values = points.map((p) => p.value);
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  const variance = values.reduce((s, v) => s + Math.pow(v - mean, 2), 0) / values.length;
  const stdDev = Math.sqrt(variance);
  if (stdDev === 0) return points;
  return points.filter((p) => Math.abs(p.value - mean) <= 3 * stdDev);
}

// GET /analytics/charts/:metric
router.get('/:metric', async (req, res) => {
  const { metric } = req.params;
  if (!SERIES_QUERIES[metric]) {
    return res.status(400).json({ error: `Unknown metric. Supported: ${Object.keys(SERIES_QUERIES).join(', ')}` });
  }
  const raw = await SERIES_QUERIES[metric](req.userId);
  const cleaned = removeOutliers(raw);
  res.json({
    metric,
    points: cleaned,
    outliersRemoved: raw.length - cleaned.length,
  });
});

module.exports = router;

