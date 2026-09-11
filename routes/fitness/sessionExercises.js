const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

// Helper: confirms the session belongs to this user before touching its children
async function getOwnedSession(sessionId, userId) {
  const session = await prisma.session.findUnique({ where: { id: sessionId } });
  if (!session || session.userId !== userId) return null;
  return session;
}

// POST /fitness/sessions/:id/exercises
router.post('/', async (req, res) => {
  const session = await getOwnedSession(req.params.id, req.userId);
  if (!session) return res.status(404).json({ error: 'Session not found' });

  const { name, order } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });

  const exercise = await prisma.sessionExercise.create({
    data: { sessionId: session.id, name, order: order ?? 0 },
    include: { sets: true },
  });
  res.status(201).json(exercise);
});

// PATCH /fitness/sessions/:id/exercises/:exId
router.patch('/:exId', async (req, res) => {
  const session = await getOwnedSession(req.params.id, req.userId);
  if (!session) return res.status(404).json({ error: 'Session not found' });

  const existing = await prisma.sessionExercise.findUnique({ where: { id: req.params.exId } });
  if (!existing || existing.sessionId !== session.id) {
    return res.status(404).json({ error: 'Exercise not found' });
  }

  const { name, order } = req.body;
  const updated = await prisma.sessionExercise.update({
    where: { id: req.params.exId },
    data: {
      ...(name !== undefined && { name }),
      ...(order !== undefined && { order }),
    },
    include: { sets: true },
  });
  res.json(updated);
});

// DELETE /fitness/sessions/:id/exercises/:exId
router.delete('/:exId', async (req, res) => {
  const session = await getOwnedSession(req.params.id, req.userId);
  if (!session) return res.status(404).json({ error: 'Session not found' });

  const existing = await prisma.sessionExercise.findUnique({ where: { id: req.params.exId } });
  if (!existing || existing.sessionId !== session.id) {
    return res.status(404).json({ error: 'Exercise not found' });
  }

  await prisma.sessionExercise.delete({ where: { id: req.params.exId } }); // cascades to sets
  res.status(204).send();
});

// POST /fitness/sessions/:id/exercises/:exId/sets
router.post('/:exId/sets', async (req, res) => {
  const session = await getOwnedSession(req.params.id, req.userId);
  if (!session) return res.status(404).json({ error: 'Session not found' });

  const exercise = await prisma.sessionExercise.findUnique({ where: { id: req.params.exId } });
  if (!exercise || exercise.sessionId !== session.id) {
    return res.status(404).json({ error: 'Exercise not found' });
  }

  const { kind, weightKg, reps, rpe, completed } = req.body;
  const set = await prisma.sessionSet.create({
    data: {
      sessionExerciseId: exercise.id,
      kind: kind || 'working',
      weightKg,
      reps,
      rpe,
      completed: !!completed,
    },
  });
  res.status(201).json(set);
});

// PATCH /fitness/sessions/:id/exercises/:exId/sets/:setId
router.patch('/:exId/sets/:setId', async (req, res) => {
  const session = await getOwnedSession(req.params.id, req.userId);
  if (!session) return res.status(404).json({ error: 'Session not found' });

  const exercise = await prisma.sessionExercise.findUnique({ where: { id: req.params.exId } });
  if (!exercise || exercise.sessionId !== session.id) {
    return res.status(404).json({ error: 'Exercise not found' });
  }

  const existing = await prisma.sessionSet.findUnique({ where: { id: req.params.setId } });
  if (!existing || existing.sessionExerciseId !== exercise.id) {
    return res.status(404).json({ error: 'Set not found' });
  }

  const { kind, weightKg, reps, rpe, completed } = req.body;
  const updated = await prisma.sessionSet.update({
    where: { id: req.params.setId },
    data: {
      ...(kind !== undefined && { kind }),
      ...(weightKg !== undefined && { weightKg }),
      ...(reps !== undefined && { reps }),
      ...(rpe !== undefined && { rpe }),
      ...(completed !== undefined && { completed }),
    },
  });
  res.json(updated);
});

// DELETE /fitness/sessions/:id/exercises/:exId/sets/:setId
router.delete('/:exId/sets/:setId', async (req, res) => {
  const session = await getOwnedSession(req.params.id, req.userId);
  if (!session) return res.status(404).json({ error: 'Session not found' });

  const exercise = await prisma.sessionExercise.findUnique({ where: { id: req.params.exId } });
  if (!exercise || exercise.sessionId !== session.id) {
    return res.status(404).json({ error: 'Exercise not found' });
  }

  const existing = await prisma.sessionSet.findUnique({ where: { id: req.params.setId } });
  if (!existing || existing.sessionExerciseId !== exercise.id) {
    return res.status(404).json({ error: 'Set not found' });
  }

  await prisma.sessionSet.delete({ where: { id: req.params.setId } });
  res.status(204).send();
});

module.exports = router;