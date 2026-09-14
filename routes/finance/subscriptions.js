const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const subscriptions = await prisma.subscription.findMany({
    where: { userId: req.userId },
    orderBy: { dueDay: 'asc' },
  });
  res.json(subscriptions);
});

router.post('/', async (req, res) => {
  const { name, amountPaise, recurrence, dueDay, lastUsedDaysAgo } = req.body;
  if (!name || amountPaise === undefined || !recurrence || !dueDay) {
    return res.status(400).json({ error: 'name, amountPaise, recurrence, and dueDay are required' });
  }
  const subscription = await prisma.subscription.create({
    data: { userId: req.userId, name, amountPaise, recurrence, dueDay, lastUsedDaysAgo },
  });
  res.status(201).json(subscription);
});

module.exports = router;