const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const investments = await prisma.investment.findMany({
    where: { userId: req.userId },
    orderBy: { createdAt: 'desc' },
  });
  res.json(investments);
});

router.post('/', async (req, res) => {
  const { name, kind, units, avgCostPaise, currentNavPaise, sipPaise, sipDay, since } = req.body;
  if (!name || !kind || units === undefined || avgCostPaise === undefined || currentNavPaise === undefined || !since) {
    return res.status(400).json({ error: 'name, kind, units, avgCostPaise, currentNavPaise, and since are required' });
  }
  const investment = await prisma.investment.create({
    data: {
      userId: req.userId, name, kind, units, avgCostPaise, currentNavPaise,
      sipPaise: sipPaise ?? 0, sipDay, since: new Date(since),
    },
  });
  res.status(201).json(investment);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.investment.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Investment not found' });
  }
  const { units, currentNavPaise, sipPaise, sipDay } = req.body;
  const updated = await prisma.investment.update({
    where: { id: req.params.id },
    data: {
      ...(units !== undefined && { units }),
      ...(currentNavPaise !== undefined && { currentNavPaise }),
      ...(sipPaise !== undefined && { sipPaise }),
      ...(sipDay !== undefined && { sipDay }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.investment.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Investment not found' });
  }
  await prisma.investment.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;