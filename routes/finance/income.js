const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const income = await prisma.income.findUnique({ where: { userId: req.userId } });
  res.json(income);
});

router.patch('/', async (req, res) => {
  const { monthlyNetPaise, label } = req.body;
  if (monthlyNetPaise === undefined) {
    return res.status(400).json({ error: 'monthlyNetPaise is required' });
  }
  const income = await prisma.income.upsert({
    where: { userId: req.userId },
    update: { monthlyNetPaise, ...(label !== undefined && { label }) },
    create: { userId: req.userId, monthlyNetPaise, label },
  });
  res.json(income);
});

module.exports = router;