const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const { from, to } = req.query;
  const sleepEntries = await prisma.sleepEntry.findMany({
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
  res.json(sleepEntries);
});

router.post('/', async (req, res) => {
  const { date, durationMinutes, quality, interruptions, bedtime, wake } = req.body;
  if (!date || durationMinutes === undefined) {
    return res.status(400).json({ error: 'date and durationMinutes are required' });
  }
  const entry = await prisma.sleepEntry.create({
    data: {
      userId: req.userId,
      date: new Date(date),
      durationMinutes,
      quality,
      interruptions,
      bedtime: bedtime ? new Date(bedtime) : undefined,
      wake: wake ? new Date(wake) : undefined,
    },
  });
  res.status(201).json(entry);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.sleepEntry.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Sleep entry not found' });
  }
  const { date, durationMinutes, quality, interruptions, bedtime, wake } = req.body;
  const updated = await prisma.sleepEntry.update({
    where: { id: req.params.id },
    data: {
      ...(date !== undefined && { date: new Date(date) }),
      ...(durationMinutes !== undefined && { durationMinutes }),
      ...(quality !== undefined && { quality }),
      ...(interruptions !== undefined && { interruptions }),
      ...(bedtime !== undefined && { bedtime: new Date(bedtime) }),
      ...(wake !== undefined && { wake: new Date(wake) }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.sleepEntry.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Sleep entry not found' });
  }
  await prisma.sleepEntry.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;