const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const history = await prisma.netWorthSnapshot.findMany({
    where: { userId: req.userId },
    orderBy: { date: 'asc' },
  });
  res.json(history);
});

router.post('/snapshot', async (req, res) => {
  const [accounts, investments, assets, debts] = await Promise.all([
    prisma.account.findMany({ where: { userId: req.userId } }),
    prisma.investment.findMany({ where: { userId: req.userId } }),
    prisma.asset.findMany({ where: { userId: req.userId } }),
    prisma.debt.findMany({ where: { userId: req.userId } }),
  ]);

  const liquidPaise = accounts.filter((a) => a.kind !== 'credit_card').reduce((s, a) => s + a.balancePaise, 0);
  const cardDebtPaise = accounts.filter((a) => a.kind === 'credit_card').reduce((s, a) => s + Math.abs(Math.min(0, a.balancePaise)), 0);
  const investedPaise = investments.reduce((s, i) => s + Math.round(i.units * i.currentNavPaise), 0);
  const assetsPaiseTotal = assets.reduce((s, a) => s + a.valuePaise, 0);
  const debtsPaise = debts.reduce((s, d) => s + d.principalPaise, 0); 

  const assetsPaise = liquidPaise + investedPaise + assetsPaiseTotal;
  const liabilitiesPaise = cardDebtPaise + debtsPaise;

  const snapshot = await prisma.netWorthSnapshot.create({
    data: {
      userId: req.userId,
      assetsPaise,
      liabilitiesPaise,
      netPaise: assetsPaise - liabilitiesPaise,
    },
  });
  res.status(201).json(snapshot);
});

module.exports = router;