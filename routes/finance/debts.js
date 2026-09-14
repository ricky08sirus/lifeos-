const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const debts = await prisma.debt.findMany({
    where: { userId: req.userId },
    orderBy: { createdAt: 'desc' },
  });
  res.json(debts);
});

router.post('/', async (req, res) => {
  const { name, kind, lender, principalPaise, annualRatePct, termMonths, startedOn, emiPaise, purchasePricePaise, downPaymentPaise } = req.body;
  if (!name || !kind || principalPaise === undefined || annualRatePct === undefined || !termMonths || !startedOn || emiPaise === undefined) {
    return res.status(400).json({ error: 'name, kind, principalPaise, annualRatePct, termMonths, startedOn, and emiPaise are required' });
  }
  const debt = await prisma.debt.create({
    data: {
      userId: req.userId, name, kind, lender, principalPaise, annualRatePct, termMonths,
      startedOn: new Date(startedOn), emiPaise, purchasePricePaise, downPaymentPaise,
    },
  });
  res.status(201).json(debt);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.debt.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Debt not found' });
  }
  const { name, emiPaise, paidMonths } = req.body;
  const updated = await prisma.debt.update({
    where: { id: req.params.id },
    data: {
      ...(name !== undefined && { name }),
      ...(emiPaise !== undefined && { emiPaise }),
      ...(paidMonths !== undefined && { paidMonths }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.debt.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Debt not found' });
  }
  await prisma.debt.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;