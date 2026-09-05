const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /fitness/sessions?from=2026-01-01&to=2026-01-31
router.get('/', async (req, res) => {
  const { from, to } = req.query;
  const sessions = await prisma.session.findMany({
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
  res.json(sessions);
});

router.post('/', async (req, res) => {
  const { date, title, muscles, status, durationMinutes, perceivedEffort } = req.body;
  if (!date || !title) {
    return res.status(400).json({ error: 'date and title are required' });
  }
  const session = await prisma.session.create({
    data: {
      userId: req.userId,
      date: new Date(date),
      title,
      muscles: muscles || [],
      status: status || 'completed',
      durationMinutes,
      perceivedEffort,
    },
  });
  res.status(201).json(session);
});

router.get('/:id', async (req, res) => {
  const session = await prisma.session.findUnique({
    where: { id: req.params.id },
    include: {
      exercises: {
        orderBy: { order: 'asc' },
        include: { sets: true },
      },
    },
  });
  if (!session || session.userId !== req.userId) {
    return res.status(404).json({ error: 'Session not found' });
  }
  res.json(session);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.session.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Session not found' });
  }
  const { status, durationMinutes, perceivedEffort, title, muscles, date } = req.body;
  const updated = await prisma.session.update({
    where: { id: req.params.id },
    data: {
      ...(status !== undefined && { status }),
      ...(durationMinutes !== undefined && { durationMinutes }),
      ...(perceivedEffort !== undefined && { perceivedEffort }),
      ...(title !== undefined && { title }),
      ...(muscles !== undefined && { muscles }),
      ...(date !== undefined && { date: new Date(date) }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.session.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Session not found' });
  }
  await prisma.session.delete({ where: { id: req.params.id } }); // cascades to exercises + sets
  res.status(204).send();
});

module.exports = router;