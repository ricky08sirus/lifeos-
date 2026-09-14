const express = require('express');
const habitsRouter = require('./habits');
const logsRouter = require('./logs');
const summaryRouter = require('./summary');

const router = express.Router();

router.use('/summary', summaryRouter); // must come before '/:id/logs' so 'summary' isn't parsed as an id
router.use('/', habitsRouter);
router.use('/:id/logs', logsRouter);

module.exports = router;