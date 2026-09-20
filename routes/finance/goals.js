const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const goals = await prisma.financialGoal.findMany({
    where: { userId: req.userId },
    orderBy: { priority: 'asc' },
  });
  res.json(goals);
});

router.post('/', async (req, res) => {
  const { name, targetPaise, savedPaise, targetDate, priority, linkedAccountId } = req.body;
  if (!name || targetPaise === undefined) {
    return res.status(400).json({ error: 'name and targetPaise are required' });
  }
  const goal = await prisma.financialGoal.create({
    data: {
      userId: req.userId, name, targetPaise, savedPaise: savedPaise ?? 0,
      targetDate: targetDate ? new Date(targetDate) : undefined,
      priority: priority ?? 1, linkedAccountId,
    },
  });
  res.status(201).json(goal);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.financialGoal.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Goal not found' });
  }
  const { savedPaise, targetPaise, priority } = req.body;
  const updated = await prisma.financialGoal.update({
    where: { id: req.params.id },
    data: {
      ...(savedPaise !== undefined && { savedPaise }),
      ...(targetPaise !== undefined && { targetPaise }),
      ...(priority !== undefined && { priority }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.financialGoal.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Goal not found' });
  }
  await prisma.financialGoal.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;