const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /finance/upcoming-dues?days=14
router.get('/', async (req, res) => {
  const windowDays = parseInt(req.query.days, 10) || 14;
  const today = new Date();

  const [bills, debts, subscriptions, insurance] = await Promise.all([
    prisma.bill.findMany({ where: { userId: req.userId } }),
    prisma.debt.findMany({ where: { userId: req.userId } }),
    prisma.subscription.findMany({ where: { userId: req.userId } }),
    prisma.insurance.findMany({ where: { userId: req.userId } }),
  ]);

  function nextOccurrence(dueDay) {
    let due = new Date(today.getFullYear(), today.getMonth(), dueDay);
    if (due < today) due = new Date(today.getFullYear(), today.getMonth() + 1, dueDay);
    return due;
  }

  const items = [];

  for (const b of bills) {
    const due = nextOccurrence(b.dueDay);
    const inDays = Math.round((due - today) / 86400000);
    if (inDays <= windowDays) items.push({ kind: 'bill', name: b.name, amountPaise: b.amountPaise, dueDate: due, inDays, autopay: b.autopay });
  }
  for (const d of debts) {
    const due = nextOccurrence(7); // simplified fixed EMI date; refine once debt has its own dueDay field
    const inDays = Math.round((due - today) / 86400000);
    if (inDays <= windowDays) items.push({ kind: 'emi', name: `${d.name} EMI`, amountPaise: d.emiPaise, dueDate: due, inDays, autopay: true });
  }
  for (const s of subscriptions) {
    const due = nextOccurrence(s.dueDay);
    const inDays = Math.round((due - today) / 86400000);
    if (inDays <= windowDays) items.push({ kind: 'subscription', name: s.name, amountPaise: s.amountPaise, dueDate: due, inDays, autopay: true });
  }
  for (const i of insurance) {
    const inDays = Math.round((new Date(i.renewalOn) - today) / 86400000);
    if (inDays >= 0 && inDays <= windowDays) items.push({ kind: 'insurance', name: `${i.provider} renewal`, amountPaise: i.premiumPaise, dueDate: i.renewalOn, inDays, autopay: false });
  }

  items.sort((a, b) => a.inDays - b.inDays);
  res.json({ windowDays, items, totalPaise: items.reduce((s, i) => s + i.amountPaise, 0) });
});

module.exports = router;