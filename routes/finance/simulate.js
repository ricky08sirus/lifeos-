const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

function emi(principalPaise, annualRatePct, termMonths) {
  if (annualRatePct === 0) return Math.round(principalPaise / termMonths);
  const r = annualRatePct / 12 / 100;
  const factor = Math.pow(1 + r, termMonths);
  return Math.round((principalPaise * r * factor) / (factor - 1));
}

// POST /finance/simulate - debt payoff simulation (snowball or avalanche)
router.post('/', async (req, res) => {
  const { strategy = 'snowball', extraMonthlyPaise = 0 } = req.body;

  const debts = await prisma.debt.findMany({ where: { userId: req.userId } });
  if (debts.length === 0) {
    return res.status(400).json({ error: 'No debts to simulate' });
  }

  let live = debts.map((d) => ({
    id: d.id, name: d.name, annualRatePct: d.annualRatePct,
    emiPaise: d.emiPaise,
    outstandingPaise: d.principalPaise - (d.emiPaise * d.paidMonths), // simplified balance
  })).filter((d) => d.outstandingPaise > 0);

  if (live.length === 0) {
    return res.json({ months: 0, totalInterestPaise: 0, message: 'All debts already paid off' });
  }

  const order = strategy === 'avalanche'
    ? [...live].sort((a, b) => b.annualRatePct - a.annualRatePct)
    : [...live].sort((a, b) => a.outstandingPaise - b.outstandingPaise);

  let month = 0, totalInterest = 0, rolling = extraMonthlyPaise;
  const clearedAt = {};

  while (order.some((d) => d.outstandingPaise > 0) && month < 600) {
    month++;
    for (const debt of order) {
      if (debt.outstandingPaise <= 0) continue;
      const interest = Math.round(debt.outstandingPaise * (debt.annualRatePct / 12 / 100));
      totalInterest += interest;
      debt.outstandingPaise += interest;
      debt.outstandingPaise -= Math.min(debt.emiPaise, debt.outstandingPaise);
    }
    let spare = rolling;
    for (const debt of order) {
      if (spare <= 0) break;
      if (debt.outstandingPaise <= 0) continue;
      const applied = Math.min(spare, debt.outstandingPaise);
      debt.outstandingPaise -= applied;
      spare -= applied;
    }
    for (const debt of order) {
      if (debt.outstandingPaise <= 0 && !clearedAt[debt.id]) {
        clearedAt[debt.id] = month;
        rolling += debt.emiPaise;
      }
    }
  }

  if (month >= 600) {
    return res.status(400).json({ error: 'Payments never clear the balance at this rate' });
  }

  res.json({
    strategy,
    months: month,
    totalInterestPaise: totalInterest,
    order: order.map((d) => d.name),
    clearedAt,
  });
});

module.exports = router;