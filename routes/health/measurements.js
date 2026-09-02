const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /health/measurements?site=waist&from=...&to=...
router.get('/', async (req, res) => {
  const { site, from, to } = req.query;
  const measurements = await prisma.measurement.findMany({
    where: {
      userId: req.userId,
      ...(site && { site }),
      ...(from || to ? {
        date: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      } : {}),
    },
    orderBy: { date: 'desc' },
  });
  res.json(measurements);
});

router.post('/', async (req, res) => {
  const { date, site, valueCm } = req.body;
  if (!date || !site || valueCm === undefined) {
    return res.status(400).json({ error: 'date, site, and valueCm are required' });
  }
  const measurement = await prisma.measurement.create({
    data: { userId: req.userId, date: new Date(date), site, valueCm },
  });
  res.status(201).json(measurement);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.measurement.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Measurement not found' });
  }
  const { date, site, valueCm } = req.body;
  const updated = await prisma.measurement.update({
    where: { id: req.params.id },
    data: {
      ...(date !== undefined && { date: new Date(date) }),
      ...(site !== undefined && { site }),
      ...(valueCm !== undefined && { valueCm }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.measurement.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Measurement not found' });
  }
  await prisma.measurement.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;