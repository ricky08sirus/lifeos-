const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const assets = await prisma.asset.findMany({
    where: { userId: req.userId },
    orderBy: { createdAt: 'desc' },
  });
  res.json(assets);
});

router.post('/', async (req, res) => {
  const { name, kind, valuePaise, acquiredOn, depreciating } = req.body;
  if (!name || !kind || valuePaise === undefined || !acquiredOn) {
    return res.status(400).json({ error: 'name, kind, valuePaise, and acquiredOn are required' });
  }
  const asset = await prisma.asset.create({
    data: { userId: req.userId, name, kind, valuePaise, acquiredOn: new Date(acquiredOn), depreciating: !!depreciating },
  });
  res.status(201).json(asset);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.asset.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Asset not found' });
  }
  const { valuePaise, depreciating } = req.body;
  const updated = await prisma.asset.update({
    where: { id: req.params.id },
    data: {
      ...(valuePaise !== undefined && { valuePaise }),
      ...(depreciating !== undefined && { depreciating }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.asset.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Asset not found' });
  }
  await prisma.asset.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;