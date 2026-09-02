const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /health/vitals?kind=resting_heart_rate
router.get('/', async (req, res) => {
  const { kind, from, to } = req.query;
  const vitals = await prisma.vital.findMany({
    where: {
      userId: req.userId,
      ...(kind && { kind }),
      ...(from || to ? {
        recordedAt: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      } : {}),
    },
    orderBy: { recordedAt: 'desc' },
  });
  res.json(vitals);
});

router.post('/', async (req, res) => {
  const { kind, value, systolic, diastolic, recordedAt } = req.body;
  if (!kind) return res.status(400).json({ error: 'kind is required' });
  if (kind === 'blood_pressure' && (systolic === undefined || diastolic === undefined)) {
    return res.status(400).json({ error: 'systolic and diastolic are required for blood_pressure' });
  }
  if (kind === 'resting_heart_rate' && value === undefined) {
    return res.status(400).json({ error: 'value is required for resting_heart_rate' });
  }

  const vital = await prisma.vital.create({
    data: {
      userId: req.userId,
      kind,
      value,
      systolic,
      diastolic,
      recordedAt: recordedAt ? new Date(recordedAt) : undefined,
    },
  });
  res.status(201).json(vital);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.vital.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Vital not found' });
  }
  const { value, systolic, diastolic, recordedAt } = req.body;
  const updated = await prisma.vital.update({
    where: { id: req.params.id },
    data: {
      ...(value !== undefined && { value }),
      ...(systolic !== undefined && { systolic }),
      ...(diastolic !== undefined && { diastolic }),
      ...(recordedAt !== undefined && { recordedAt: new Date(recordedAt) }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.vital.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Vital not found' });
  }
  await prisma.vital.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;