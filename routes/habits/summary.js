const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');
const { habitStreak } = require('../../lib/calc');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const habits = await prisma.habit.findMany({
    where: { userId: req.userId, archivedAt: null },
    include: { logs: { orderBy: { date: 'desc' }, take: 30 } },
  });

  const results = habits.map((habit) => {
    // last 30 days as "scheduled dates" - simplified; refine later per cadence/customDays
    const scheduledDates = Array.from({ length: 30 }, (_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - i);
      return d;
    });

    return {
      habitId: habit.id,
      name: habit.name,
      currentStreak: habitStreak(habit.logs, scheduledDates),
      last30DaysLogged: habit.logs.length,
    };
  });

  res.json({ habits: results });
});

module.exports = router;