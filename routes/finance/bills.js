const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const bills = await prisma.bill.findMany({
    where: { userId: req.userId },
    orderBy: { dueDay: 'asc' },
  });
  res.json(bills);
});

router.post('/', async (req, res) => {
  const { name, amountPaise, dueDay, recurrence, autopay, category, isVariable } = req.body;
  if (!name || amountPaise === undefined || !dueDay || !recurrence) {
    return res.status(400).json({ error: 'name, amountPaise, dueDay, and recurrence are required' });
  }
  const bill = await prisma.bill.create({
    data: { userId: req.userId, name, amountPaise, dueDay, recurrence, autopay: !!autopay, category, isVariable: !!isVariable },
  });
  res.status(201).json(bill);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.bill.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Bill not found' });
  }
  const { name, amountPaise, dueDay, recurrence, autopay, category, isVariable } = req.body;
  const updated = await prisma.bill.update({
    where: { id: req.params.id },
    data: {
      ...(name !== undefined && { name }),
      ...(amountPaise !== undefined && { amountPaise }),
      ...(dueDay !== undefined && { dueDay }),
      ...(recurrence !== undefined && { recurrence }),
      ...(autopay !== undefined && { autopay }),
      ...(category !== undefined && { category }),
      ...(isVariable !== undefined && { isVariable }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.bill.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Bill not found' });
  }
  await prisma.bill.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;
