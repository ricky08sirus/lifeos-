const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');
const { trainingVolume, estimatedOneRepMax, trainingAdherence } = require('../../lib/calc');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

  const recentSessions = await prisma.session.findMany({
    where: { userId: req.userId, date: { gte: thirtyDaysAgo } },
    include: { exercises: { include: { sets: true } } },
  });

  const completedCount = recentSessions.filter((s) => s.status === 'completed').length;
  const totalCount = recentSessions.length;

  const allSets = recentSessions.flatMap((s) => s.exercises.flatMap((ex) => ex.sets));
  const totalVolume = trainingVolume(allSets);

  // Best estimated 1RM per exercise name, across the last 30 days
  const bestByExercise = {};
  for (const session of recentSessions) {
    for (const ex of session.exercises) {
      for (const set of ex.sets) {
        if (!set.completed || !set.weightKg || !set.reps) continue;
        const oneRm = estimatedOneRepMax(set.weightKg, set.reps);
        if (!bestByExercise[ex.name] || oneRm > bestByExercise[ex.name]) {
          bestByExercise[ex.name] = oneRm;
        }
      }
    }
  }

  res.json({
    last30Days: {
      sessionsCompleted: completedCount,
      sessionsPlanned: totalCount,
      adherencePercent: trainingAdherence(totalCount, completedCount),
      totalVolumeKg: totalVolume,
    },
    estimatedOneRepMaxByExercise: bestByExercise,
  });
});

module.exports = router;