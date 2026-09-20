const express = require('express');
const requireAuth = require('../middleware/auth');
const prisma = require('../lib/prisma');

const router = express.Router();
router.use(requireAuth);

async function eventsInRange(userId, from, to) {
  const [sessions, bills, appointments, debts] = await Promise.all([
    prisma.session.findMany({ where: { userId, date: { gte: from, lte: to } } }),
    prisma.bill.findMany({ where: { userId } }), // recurring by dueDay, filtered below
    prisma.appointment.findMany({ where: { userId, scheduledAt: { gte: from, lte: to } } }),
    prisma.debt.findMany({ where: { userId } }),
  ]);

  const events = [];
  for (const s of sessions) events.push({ kind: 'workout', date: s.date, title: s.title, status: s.status });
  for (const a of appointments) events.push({ kind: 'appointment', date: a.scheduledAt, title: a.title, provider: a.provider });

  // Bills/debts are monthly recurring by day-of-month, so expand into any month inside the range
  const cursor = new Date(from);
  while (cursor <= to) {
    const dom = cursor.getDate();
    for (const b of bills) {
      if (b.dueDay === dom) events.push({ kind: 'bill', date: new Date(cursor), title: b.name, amountPaise: b.amountPaise });
    }
    for (const d of debts) {
      if (dom === 7) events.push({ kind: 'emi', date: new Date(cursor), title: `${d.name} EMI`, amountPaise: d.emiPaise });
    }
    cursor.setDate(cursor.getDate() + 1);
  }

  return events.sort((a, b) => new Date(a.date) - new Date(b.date));
}

// GET /calendar?from=...&to=...
router.get('/', async (req, res) => {
  const from = req.query.from ? new Date(req.query.from) : new Date();
  const to = req.query.to ? new Date(req.query.to) : new Date(Date.now() + 30 * 86400000);
  const events = await eventsInRange(req.userId, from, to);
  res.json({ from, to, events });
});

// GET /calendar/day/:date
router.get('/day/:date', async (req, res) => {
  const day = new Date(req.params.date);
  const start = new Date(day.setHours(0, 0, 0, 0));
  const end = new Date(day.setHours(23, 59, 59, 999));
  const events = await eventsInRange(req.userId, start, end);
  res.json({ date: req.params.date, events });
});

module.exports = router;
