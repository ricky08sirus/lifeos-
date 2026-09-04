const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const appointments = await prisma.appointment.findMany({
    where: { userId: req.userId },
    orderBy: { scheduledAt: 'asc' },
  });
  res.json(appointments);
});

router.post('/', async (req, res) => {
  const { title, scheduledAt, provider, location } = req.body;
  if (!title || !scheduledAt) {
    return res.status(400).json({ error: 'title and scheduledAt are required' });
  }
  const appointment = await prisma.appointment.create({
    data: { userId: req.userId, title, scheduledAt: new Date(scheduledAt), provider, location },
  });
  res.status(201).json(appointment);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.appointment.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Appointment not found' });
  }
  const { title, scheduledAt, provider, location } = req.body;
  const updated = await prisma.appointment.update({
    where: { id: req.params.id },
    data: {
      ...(title !== undefined && { title }),
      ...(scheduledAt !== undefined && { scheduledAt: new Date(scheduledAt) }),
      ...(provider !== undefined && { provider }),
      ...(location !== undefined && { location }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.appointment.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Appointment not found' });
  }
  await prisma.appointment.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;