const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');
const { targetAdherence } = require('../../lib/calc');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const date = req.query.date ? new Date(req.query.date) : new Date();
  const startOfDay = new Date(date.setHours(0, 0, 0, 0));
  const endOfDay = new Date(date.setHours(23, 59, 59, 999));

  const goal = await prisma.goal.findUnique({ where: { userId: req.userId } });

  const meals = await prisma.meal.findMany({
    where: { userId: req.userId, date: { gte: startOfDay, lte: endOfDay } },
  });

  const totals = meals.reduce((acc, m) => ({
    calories: acc.calories + (m.calories || 0),
    protein: acc.protein + (m.protein || 0),
    carbs: acc.carbs + (m.carbs || 0),
    fat: acc.fat + (m.fat || 0),
  }), { calories: 0, protein: 0, carbs: 0, fat: 0 });

  const waterEntries = await prisma.waterIntake.findMany({
    where: { userId: req.userId, date: { gte: startOfDay, lte: endOfDay } },
  });
  const totalWaterMl = waterEntries.reduce((sum, w) => sum + w.amountMl, 0);

  res.json({
    date: startOfDay.toISOString().split('T')[0],
    totals: { ...totals, waterMl: totalWaterMl },
    targets: {
      calories: goal?.dailyCalories ?? null,
      protein: goal?.dailyProteinG ?? null,
      carbs: goal?.dailyCarbsG ?? null,
      fat: goal?.dailyFatG ?? null,
      waterMl: goal?.dailyWaterMl ?? null,
    },
    adherencePercent: {
      calories: targetAdherence([totals.calories], goal?.dailyCalories),
      protein: targetAdherence([totals.protein], goal?.dailyProteinG),
      water: targetAdherence([totalWaterMl], goal?.dailyWaterMl),
    },
  });
});

module.exports = router;