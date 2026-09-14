const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const categories = await prisma.category.findMany({
    where: { userId: req.userId },
    orderBy: { name: 'asc' },
  });
  res.json(categories);
});

router.post('/', async (req, res) => {
  const { name, group, isNeed, budgetPaise } = req.body;
  if (!name || !group) {
    return res.status(400).json({ error: 'name and group are required' });
  }
  const category = await prisma.category.create({
    data: { userId: req.userId, name, group, isNeed: isNeed ?? true, budgetPaise },
  });
  res.status(201).json(category);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.category.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Category not found' });
  }
  const { name, group, isNeed, budgetPaise } = req.body;
  const updated = await prisma.category.update({
    where: { id: req.params.id },
    data: {
      ...(name !== undefined && { name }),
      ...(group !== undefined && { group }),
      ...(isNeed !== undefined && { isNeed }),
      ...(budgetPaise !== undefined && { budgetPaise }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.category.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Category not found' });
  }
  await prisma.category.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;