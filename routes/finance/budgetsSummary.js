const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

  const categories = await prisma.category.findMany({ where: { userId: req.userId } });
  const transactions = await prisma.transaction.findMany({
    where: { userId: req.userId, date: { gte: startOfMonth, lte: endOfMonth } },
  });

  const summary = categories.map((cat) => {
    const spentPaise = transactions
      .filter((t) => t.categoryId === cat.id)
      .reduce((sum, t) => sum + t.amountPaise, 0);
    return {
      categoryId: cat.id,
      name: cat.name,
      group: cat.group,
      budgetPaise: cat.budgetPaise || 0,
      spentPaise,
      remainingPaise: (cat.budgetPaise || 0) - spentPaise,
      percentUsed: cat.budgetPaise ? Math.round((spentPaise / cat.budgetPaise) * 100) : null,
    };
  });

  res.json({ month: startOfMonth.toISOString().slice(0, 7), categories: summary });
});

module.exports = router;