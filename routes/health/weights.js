const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /health/weights?from=2026-01-01&to=2026-01-31
router.get('/', async (req, res) => {
  const { from, to } = req.query;
  const weights = await prisma.weight.findMany({
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
  res.json(weights);
});

router.post('/', async (req, res) => {
  const { date, kg } = req.body;
  if (!date || kg === undefined) {
    return res.status(400).json({ error: 'date and kg are required' });
  }
  const weight = await prisma.weight.create({
    data: { userId: req.userId, date: new Date(date), kg },
  });
  res.status(201).json(weight);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.weight.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Weight entry not found' });
  }
  const { date, kg } = req.body;
  const updated = await prisma.weight.update({
    where: { id: req.params.id },
    data: {
      ...(date !== undefined && { date: new Date(date) }),
      ...(kg !== undefined && { kg }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.weight.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Weight entry not found' });
  }
  await prisma.weight.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;