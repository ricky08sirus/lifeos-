const express = require('express');
const incomeRouter = require('./income');
const accountsRouter = require('./accounts');
const categoriesRouter = require('./categories');
const transactionsRouter = require('./transactions');
const debtsRouter = require('./debts');
const billsRouter = require('./bills');
const subscriptionsRouter = require('./subscriptions');

const router = express.Router();

router.use('/income', incomeRouter);
router.use('/accounts', accountsRouter);
router.use('/categories', categoriesRouter);
router.use('/transactions', transactionsRouter);
router.use('/debts', debtsRouter);
router.use('/bills', billsRouter);
router.use('/subscriptions', subscriptionsRouter);

module.exports = router;