const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');
const { pearsonCorrelation, alignByDate } = require('../../lib/analytics');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const from = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const insights = [];

  // Rule 1: sleep vs training volume
  const sleep = await prisma.sleepEntry.findMany({ where: { userId: req.userId, date: { gte: from } } });
  const sessions = await prisma.session.findMany({
    where: { userId: req.userId, date: { gte: from }, status: 'completed' },
    include: { exercises: { include: { sets: true } } },
  });
  const sleepSeries = sleep.map((s) => ({ date: s.date.toISOString().slice(0, 10), value: s.durationMinutes }));
  const volumeSeries = sessions.map((s) => ({
    date: s.date.toISOString().slice(0, 10),
    value: s.exercises.flatMap((e) => e.sets).filter((set) => set.kind !== 'warmup' && set.completed)
      .reduce((sum, set) => sum + (set.weightKg || 0) * (set.reps || 0), 0),
  }));
  const sleepVsVolume = pearsonCorrelation(alignByDate(sleepSeries, volumeSeries));
  if (sleepVsVolume !== null) {
    insights.push({
      id: 'sleep-vs-training-volume',
      title: 'Sleep and training volume',
      correlation: sleepVsVolume,
      strength: Math.abs(sleepVsVolume) < 0.2 ? 'negligible' : Math.abs(sleepVsVolume) < 0.4 ? 'weak' : Math.abs(sleepVsVolume) < 0.6 ? 'moderate' : 'strong',
      direction: sleepVsVolume > 0 ? 'together' : 'opposite',
      sampleSize: alignByDate(sleepSeries, volumeSeries).length,
      description: `Over the last 30 days, sleep duration and training volume ${Math.abs(sleepVsVolume) < 0.2 ? 'show no clear relationship' : sleepVsVolume > 0 ? 'tended to move together' : 'tended to move in opposite directions'}.`,
    });
  }

  // Rule 2: spending vs mood/wellbeing
  const wellbeing = await prisma.wellbeingEntry.findMany({ where: { userId: req.userId, date: { gte: from } } });
  const transactions = await prisma.transaction.findMany({ where: { userId: req.userId, date: { gte: from } } });
  const spendByDay = new Map();
  for (const t of transactions) {
    const key = t.date.toISOString().slice(0, 10);
    spendByDay.set(key, (spendByDay.get(key) || 0) + t.amountPaise);
  }
  const spendSeries = [...spendByDay.entries()].map(([date, value]) => ({ date, value }));
  const moodSeries = wellbeing.map((w) => ({ date: w.date.toISOString().slice(0, 10), value: w.mood }));
  const spendVsMood = pearsonCorrelation(alignByDate(spendSeries, moodSeries));
  if (spendVsMood !== null) {
    insights.push({
      id: 'spend-vs-mood',
      title: 'Spending and mood',
      correlation: spendVsMood,
      strength: Math.abs(spendVsMood) < 0.2 ? 'negligible' : Math.abs(spendVsMood) < 0.4 ? 'weak' : Math.abs(spendVsMood) < 0.6 ? 'moderate' : 'strong',
      direction: spendVsMood > 0 ? 'together' : 'opposite',
      sampleSize: alignByDate(spendSeries, moodSeries).length,
      description: `Daily spending and self-reported mood ${Math.abs(spendVsMood) < 0.2 ? 'show no clear relationship' : spendVsMood > 0 ? 'tended to move together' : 'tended to move in opposite directions'} over the last 30 days.`,
    });
  }

  res.json({ insights, note: 'These are statistical associations in your own data, not causes.' });
});

module.exports = router;


