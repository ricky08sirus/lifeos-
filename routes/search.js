const express = require('express');
const requireAuth = require('../middleware/auth');
const prisma = require('../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /search?q=...
router.get('/', async (req, res) => {
  const q = (req.query.q || '').trim();
  if (q.length < 2) {
    return res.status(400).json({ error: 'q must be at least 2 characters' });
  }
  const userId = req.userId;

  const [meals, transactions, sessions, habits, medications] = await Promise.all([
    prisma.meal.findMany({ where: { userId, label: { contains: q, mode: 'insensitive' } }, take: 10 }),
    prisma.transaction.findMany({ where: { userId, merchant: { contains: q, mode: 'insensitive' } }, take: 10 }),
    prisma.session.findMany({ where: { userId, title: { contains: q, mode: 'insensitive' } }, take: 10 }),
    prisma.habit.findMany({ where: { userId, name: { contains: q, mode: 'insensitive' } }, take: 10 }),
    prisma.medication.findMany({ where: { userId, name: { contains: q, mode: 'insensitive' } }, take: 10 }),
  ]);

  res.json({
    query: q,
    results: [
      ...meals.map((m) => ({ type: 'meal', id: m.id, label: m.label, date: m.date })),
      ...transactions.map((t) => ({ type: 'transaction', id: t.id, label: t.merchant, date: t.date })),
      ...sessions.map((s) => ({ type: 'session', id: s.id, label: s.title, date: s.date })),
      ...habits.map((h) => ({ type: 'habit', id: h.id, label: h.name })),
      ...medications.map((m) => ({ type: 'medication', id: m.id, label: m.name })),
    ],
  });
});

module.exports = router;
