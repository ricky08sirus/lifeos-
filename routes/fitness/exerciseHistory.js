const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /fitness/exercises/:name/history
router.get('/:name/history', async (req, res) => {
  const sets = await prisma.sessionSet.findMany({
    where: {
      sessionExercise: {
        name: req.params.name,
        session: { userId: req.userId },
      },
    },
    include: {
      sessionExercise: {
        include: { session: { select: { date: true } } },
      },
    },
    orderBy: { sessionExercise: { session: { date: 'desc' } } },
  });

  const history = sets.map((s) => ({
    date: s.sessionExercise.session.date,
    kind: s.kind,
    weightKg: s.weightKg,
    reps: s.reps,
    rpe: s.rpe,
    completed: s.completed,
  }));

  res.json(history);
});

module.exports = router;