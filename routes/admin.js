const express = require('express');
const { getStats } = require('../lib/stats');

const router = express.Router();

router.get('/stats', (req, res) => {
  res.json({ endpointHitCounts: getStats() });
});

module.exports = router;