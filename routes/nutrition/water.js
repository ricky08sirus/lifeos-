const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const { from, to } = req.query;
  const entries = await prisma.waterIntake.findMany({
    where: {
      userId: req.userId,
      ...(from || to ? {
        date: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      } : {}),
    },
    orderBy: { date: 'desc' },
  });
  res.json(entries);
});

router.post('/', async (req, res) => {
  const { date, amountMl } = req.body;
  if (!date || amountMl === undefined) {
    return res.status(400).json({ error: 'date and amountMl are required' });
  }
  const entry = await prisma.waterIntake.create({
    data: { userId: req.userId, date: new Date(date), amountMl },
  });
  res.status(201).json(entry);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.waterIntake.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Water entry not found' });
  }
  await prisma.waterIntake.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;