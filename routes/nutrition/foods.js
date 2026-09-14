const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router();
router.use(requireAuth);

// GET /nutrition/foods?q=chicken - filtered by the user's dietType automatically
router.get('/', async (req, res) => {
  const user = await prisma.user.findUnique({ where: { id: req.userId }, select: { dietType: true } });
  const { q } = req.query;

  const foods = await prisma.foodItem.findMany({
    where: {
      userId: req.userId,
      ...(q && { name: { contains: q, mode: 'insensitive' } }),
      ...(user?.dietType && { dietTags: { has: user.dietType } }),
    },
    orderBy: { name: 'asc' },
  });
  res.json(foods);
});

router.post('/', async (req, res) => {
  const { name, dietTags, calories, protein, carbs, fat } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });

  const food = await prisma.foodItem.create({
    data: { userId: req.userId, name, dietTags: dietTags || [], calories, protein, carbs, fat },
  });
  res.status(201).json(food);
});

module.exports = router;