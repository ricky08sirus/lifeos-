const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const habits = await prisma.habit.findMany({
    where: { userId: req.userId, archivedAt: null },
    orderBy: { createdAt: 'desc' },
  });
  res.json(habits);
});

router.post('/', async (req, res) => {
  const { name, cadence, customDays, metricType, target } = req.body;
  if (!name || !cadence || !metricType) {
    return res.status(400).json({ error: 'name, cadence, and metricType are required' });
  }
  const habit = await prisma.habit.create({
    data: { userId: req.userId, name, cadence, customDays: customDays || [], metricType, target },
  });
  res.status(201).json(habit);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.habit.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Habit not found' });
  }
  const { name, cadence, customDays, metricType, target } = req.body;
  const updated = await prisma.habit.update({
    where: { id: req.params.id },
    data: {
      ...(name !== undefined && { name }),
      ...(cadence !== undefined && { cadence }),
      ...(customDays !== undefined && { customDays }),
      ...(metricType !== undefined && { metricType }),
      ...(target !== undefined && { target }),
    },
  });
  res.json(updated);
});

// "Archive/delete" per your spec - soft delete via archivedAt, safer than hard delete since logs reference it
router.delete('/:id', async (req, res) => {
  const existing = await prisma.habit.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Habit not found' });
  }
  await prisma.habit.update({ where: { id: req.params.id }, data: { archivedAt: new Date() } });
  res.status(204).send();
});

module.exports = router;