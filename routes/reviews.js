const express = require('express');
const requireAuth = require('../middleware/auth');
const prisma = require('../lib/prisma');

const router = express.Router();
router.use(requireAuth);

async function generateWeeklyReview(userId) {
  const from = new Date(Date.now() - 7 * 86400000);

  const [weights, sessions, meals, habits, transactions] = await Promise.all([
    prisma.weight.findMany({ where: { userId, date: { gte: from } } }),
    prisma.session.findMany({ where: { userId, date: { gte: from } } }),
    prisma.meal.findMany({ where: { userId, date: { gte: from } } }),
    prisma.habit.findMany({ where: { userId, archivedAt: null }, include: { logs: { where: { date: { gte: from } } } } }),
    prisma.transaction.findMany({ where: { userId, date: { gte: from } } }),
  ]);

  const completedSessions = sessions.filter((s) => s.status === 'completed').length;
  const totalCalories = meals.reduce((sum, m) => sum + (m.calories || 0), 0);
  const totalSpendPaise = transactions.reduce((sum, t) => sum + t.amountPaise, 0);
  const habitCompletionRate = habits.length
    ? Math.round((habits.reduce((sum, h) => sum + h.logs.filter((l) => l.status === 'done').length, 0) / (habits.length * 7)) * 100)
    : null;

  return {
    weekStart: from.toISOString().slice(0, 10),
    weekEnd: new Date().toISOString().slice(0, 10),
    summary: {
      weightEntriesLogged: weights.length,
      sessionsCompleted: completedSessions,
      sessionsTotal: sessions.length,
      mealsLogged: meals.length,
      avgDailyCalories: meals.length ? Math.round(totalCalories / 7) : null,
      habitCompletionRate,
      totalSpendPaise,
    },
  };
}

router.get('/weekly', async (req, res) => {
  const review = await generateWeeklyReview(req.userId);
  res.json(review);
});

router.post('/weekly/generate', async (req, res) => {
  const review = await generateWeeklyReview(req.userId);
  res.status(201).json(review);
});

module.exports = router;

