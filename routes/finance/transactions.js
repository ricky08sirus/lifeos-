const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /finance/transactions?accountId=...&categoryId=...&from=...&to=...
router.get('/', async (req, res) => {
  const { accountId, categoryId, from, to } = req.query;
  const transactions = await prisma.transaction.findMany({
    where: {
      userId: req.userId,
      ...(accountId && { accountId }),
      ...(categoryId && { categoryId }),
      ...(from || to ? {
        date: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      } : {}),
    },
    orderBy: { date: 'desc' },
  });
  res.json(transactions);
});

router.post('/', async (req, res) => {
  const { merchant, amountPaise, categoryId, accountId, date } = req.body;
  if (!merchant || amountPaise === undefined || !accountId || !date) {
    return res.status(400).json({ error: 'merchant, amountPaise, accountId, and date are required' });
  }

  const account = await prisma.account.findUnique({ where: { id: accountId } });
  if (!account || account.userId !== req.userId) {
    return res.status(400).json({ error: 'Invalid accountId' });
  }

  const transaction = await prisma.transaction.create({
    data: { userId: req.userId, merchant, amountPaise, categoryId, accountId, date: new Date(date) },
  });
  res.status(201).json(transaction);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.transaction.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Transaction not found' });
  }
  const { merchant, amountPaise, categoryId, accountId, date } = req.body;
  const updated = await prisma.transaction.update({
    where: { id: req.params.id },
    data: {
      ...(merchant !== undefined && { merchant }),
      ...(amountPaise !== undefined && { amountPaise }),
      ...(categoryId !== undefined && { categoryId }),
      ...(accountId !== undefined && { accountId }),
      ...(date !== undefined && { date: new Date(date) }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.transaction.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Transaction not found' });
  }
  await prisma.transaction.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;