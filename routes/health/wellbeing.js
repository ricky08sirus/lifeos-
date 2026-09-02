const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const { from, to } = req.query;
  const entries = await prisma.wellbeingEntry.findMany({
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
  const { date, mood, stress, energy, soreness, fatigue } = req.body;
  if (!date) {
    return res.status(400).json({ error: 'date is required' });
  }
  const entry = await prisma.wellbeingEntry.create({
    data: { userId: req.userId, date: new Date(date), mood, stress, energy, soreness, fatigue },
  });
  res.status(201).json(entry);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.wellbeingEntry.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Wellbeing entry not found' });
  }
  const { date, mood, stress, energy, soreness, fatigue } = req.body;
  const updated = await prisma.wellbeingEntry.update({
    where: { id: req.params.id },
    data: {
      ...(date !== undefined && { date: new Date(date) }),
      ...(mood !== undefined && { mood }),
      ...(stress !== undefined && { stress }),
      ...(energy !== undefined && { energy }),
      ...(soreness !== undefined && { soreness }),
      ...(fatigue !== undefined && { fatigue }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.wellbeingEntry.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Wellbeing entry not found' });
  }
  await prisma.wellbeingEntry.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;