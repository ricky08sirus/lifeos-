const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const accounts = await prisma.account.findMany({
    where: { userId: req.userId },
    orderBy: { createdAt: 'desc' },
  });
  res.json(accounts);
});

router.post('/', async (req, res) => {
  const { name, kind, institution, maskedNumber, balancePaise, isPrimary, limitPaise, statementDay, dueDay } = req.body;
  if (!name || !kind) {
    return res.status(400).json({ error: 'name and kind are required' });
  }
  const account = await prisma.account.create({
    data: {
      userId: req.userId, name, kind, institution, maskedNumber,
      balancePaise: balancePaise ?? 0, isPrimary: !!isPrimary,
      limitPaise, statementDay, dueDay,
    },
  });
  res.status(201).json(account);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.account.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Account not found' });
  }
  const { name, balancePaise, isPrimary, limitPaise, statementDay, dueDay } = req.body;
  const updated = await prisma.account.update({
    where: { id: req.params.id },
    data: {
      ...(name !== undefined && { name }),
      ...(balancePaise !== undefined && { balancePaise }),
      ...(isPrimary !== undefined && { isPrimary }),
      ...(limitPaise !== undefined && { limitPaise }),
      ...(statementDay !== undefined && { statementDay }),
      ...(dueDay !== undefined && { dueDay }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.account.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Account not found' });
  }
  await prisma.account.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;