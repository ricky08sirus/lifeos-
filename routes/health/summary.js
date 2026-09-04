const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');
const { bmi, weightTrend } = require('../../lib/calc');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.userId },
    select: { heightCm: true },
  });

  const recentWeights = await prisma.weight.findMany({
    where: { userId: req.userId },
    orderBy: { date: 'desc' },
    take: 7,
  });

  const latestWeight = recentWeights[0]?.kg ?? null;

  const latestRestingHr = await prisma.vital.findFirst({
    where: { userId: req.userId, kind: 'resting_heart_rate' },
    orderBy: { recordedAt: 'desc' },
  });

  const latestBloodPressure = await prisma.vital.findFirst({
    where: { userId: req.userId, kind: 'blood_pressure' },
    orderBy: { recordedAt: 'desc' },
  });

  res.json({
    bmi: latestWeight ? bmi(latestWeight, user?.heightCm) : null,
    latestWeightKg: latestWeight,
    weightTrend7Day: weightTrend(recentWeights),
    latestVitals: {
      restingHeartRate: latestRestingHr?.value ?? null,
      bloodPressure: latestBloodPressure
        ? { systolic: latestBloodPressure.systolic, diastolic: latestBloodPressure.diastolic }
        : null,
    },
  });
});

module.exports = router;