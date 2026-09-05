const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const plans = await prisma.trainingPlan.findMany({
    where: { userId: req.userId },
    orderBy: { createdAt: 'desc' },
  });
  res.json(plans);
});

router.post('/', async (req, res) => {
  const { name, targetMuscleGroups, exercises } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });

  const plan = await prisma.trainingPlan.create({
    data: {
      userId: req.userId,
      name,
      targetMuscleGroups: targetMuscleGroups || [],
      exercises: {
        create: (exercises || []).map((ex, i) => ({
          name: ex.name,
          order: ex.order ?? i,
          prescribedSets: ex.prescribedSets,
          prescribedReps: ex.prescribedReps,
        })),
      },
    },
    include: { exercises: { orderBy: { order: 'asc' } } },
  });
  res.status(201).json(plan);
});

router.get('/:id', async (req, res) => {
  const plan = await prisma.trainingPlan.findUnique({
    where: { id: req.params.id },
    include: { exercises: { orderBy: { order: 'asc' } } },
  });
  if (!plan || plan.userId !== req.userId) {
    return res.status(404).json({ error: 'Plan not found' });
  }
  res.json(plan);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.trainingPlan.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Plan not found' });
  }
  const { name, targetMuscleGroups } = req.body;
  const updated = await prisma.trainingPlan.update({
    where: { id: req.params.id },
    data: {
      ...(name !== undefined && { name }),
      ...(targetMuscleGroups !== undefined && { targetMuscleGroups }),
    },
    include: { exercises: { orderBy: { order: 'asc' } } },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.trainingPlan.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Plan not found' });
  }
  await prisma.trainingPlan.delete({ where: { id: req.params.id } }); // cascades to exercises
  res.status(204).send();
});

module.exports = router;