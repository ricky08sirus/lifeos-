const express = require('express');
const requireAuth = require('../middleware/auth');
const prisma = require('../lib/prisma');

const router = express.Router();

router.get('/me', requireAuth, async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.userId },
    select: {
      id: true, email: true, createdAt: true,
      displayName: true, dateOfBirth: true, heightCm: true,
      sexAtBirth: true, activityLevel: true, dietType: true, restingHrBaseline: true,
    },
  });
  res.json(user);
});

router.patch('/me', requireAuth, async (req, res) => {
  const { displayName, dateOfBirth, heightCm, sexAtBirth, activityLevel, dietType, restingHrBaseline } = req.body;

  const user = await prisma.user.update({
    where: { id: req.userId },
    data: {
      ...(displayName !== undefined && { displayName }),
      ...(dateOfBirth !== undefined && { dateOfBirth: new Date(dateOfBirth) }),
      ...(heightCm !== undefined && { heightCm }),
      ...(sexAtBirth !== undefined && { sexAtBirth }),
      ...(activityLevel !== undefined && { activityLevel }),
      ...(dietType !== undefined && { dietType }),
      ...(restingHrBaseline !== undefined && { restingHrBaseline }),
    },
    select: {
      id: true, email: true, displayName: true, dateOfBirth: true, heightCm: true,
      sexAtBirth: true, activityLevel: true, dietType: true, restingHrBaseline: true,
    },
  });
  res.json(user);
});

router.get('/me/preferences', requireAuth, async (req, res) => {
  const prefs = await prisma.preference.upsert({
    where: { userId: req.userId },
    update: {},
    create: { userId: req.userId },
  });
  res.json(prefs);
});

router.patch('/me/preferences', requireAuth, async (req, res) => {
  const { currencyCode, locale, dateFormat, units, weekStartsOn } = req.body;

  const prefs = await prisma.preference.upsert({
    where: { userId: req.userId },
    update: {
      ...(currencyCode !== undefined && { currencyCode }),
      ...(locale !== undefined && { locale }),
      ...(dateFormat !== undefined && { dateFormat }),
      ...(units !== undefined && { units }),
      ...(weekStartsOn !== undefined && { weekStartsOn }),
    },
    create: {
      userId: req.userId,
      ...(currencyCode !== undefined && { currencyCode }),
      ...(locale !== undefined && { locale }),
      ...(dateFormat !== undefined && { dateFormat }),
      ...(units !== undefined && { units }),
      ...(weekStartsOn !== undefined && { weekStartsOn }),
    },
  });
  res.json(prefs);
});

router.get('/me/goals', requireAuth, async (req, res) => {
  const goal = await prisma.goal.upsert({
    where: { userId: req.userId },
    update: {},
    create: { userId: req.userId },
  });
  res.json(goal);
});

router.patch('/me/goals', requireAuth, async (req, res) => {
  const { primaryGoal, targetWeightKg, dailyCalories, dailyProteinG, dailyCarbsG, dailyFatG, dailyWaterMl, dailySleepMinutes, workoutsPerWeek } = req.body;

  const data = {
    ...(primaryGoal !== undefined && { primaryGoal }),
    ...(targetWeightKg !== undefined && { targetWeightKg }),
    ...(dailyCalories !== undefined && { dailyCalories }),
    ...(dailyProteinG !== undefined && { dailyProteinG }),
    ...(dailyCarbsG !== undefined && { dailyCarbsG }),
    ...(dailyFatG !== undefined && { dailyFatG }),
    ...(dailyWaterMl !== undefined && { dailyWaterMl }),
    ...(dailySleepMinutes !== undefined && { dailySleepMinutes }),
    ...(workoutsPerWeek !== undefined && { workoutsPerWeek }),
  };

  const goal = await prisma.goal.upsert({
    where: { userId: req.userId },
    update: data,
    create: { userId: req.userId, ...data },
  });
  res.json(goal);
});

module.exports = router;