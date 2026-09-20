const express = require('express');
const incomeRouter = require('./income');
const accountsRouter = require('./accounts');
const categoriesRouter = require('./categories');
const transactionsRouter = require('./transactions');
const debtsRouter = require('./debts');
const billsRouter = require('./bills');
const subscriptionsRouter = require('./subscriptions');
const investmentsRouter = require('./investments');
const assetsRouter = require('./assets');
const goalsRouter = require('./goals');
const insuranceRouter = require('./insurance');
const netWorthRouter = require('./netWorth');
const budgetsSummaryRouter = require('./budgetsSummary');
const upcomingDuesRouter = require('./upcomingDues');
const simulateRouter = require('./simulate');

const router = express.Router();

router.use('/income', incomeRouter);
router.use('/accounts', accountsRouter);
router.use('/categories', categoriesRouter);
router.use('/transactions', transactionsRouter);
router.use('/debts', debtsRouter);
router.use('/bills', billsRouter);
router.use('/subscriptions', subscriptionsRouter);
router.use('/investments', investmentsRouter);
router.use('/assets', assetsRouter);
router.use('/goals', goalsRouter);
router.use('/insurance', insuranceRouter);
router.use('/net-worth', netWorthRouter);
router.use('/budgets/summary', budgetsSummaryRouter);
router.use('/upcoming-dues', upcomingDuesRouter);
router.use('/simulate', simulateRouter);

module.exports = router;