const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const policies = await prisma.insurance.findMany({
    where: { userId: req.userId },
    orderBy: { renewalOn: 'asc' },
  });
  res.json(policies);
});

router.post('/', async (req, res) => {
  const { kind, provider, coverPaise, premiumPaise, renewalOn, frequency } = req.body;
  if (!kind || !provider || coverPaise === undefined || premiumPaise === undefined || !renewalOn || !frequency) {
    return res.status(400).json({ error: 'kind, provider, coverPaise, premiumPaise, renewalOn, and frequency are required' });
  }
  const policy = await prisma.insurance.create({
    data: { userId: req.userId, kind, provider, coverPaise, premiumPaise, renewalOn: new Date(renewalOn), frequency },
  });
  res.status(201).json(policy);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.insurance.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Policy not found' });
  }
  const { coverPaise, premiumPaise, renewalOn } = req.body;
  const updated = await prisma.insurance.update({
    where: { id: req.params.id },
    data: {
      ...(coverPaise !== undefined && { coverPaise }),
      ...(premiumPaise !== undefined && { premiumPaise }),
      ...(renewalOn !== undefined && { renewalOn: new Date(renewalOn) }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.insurance.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Policy not found' });
  }
  await prisma.insurance.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;