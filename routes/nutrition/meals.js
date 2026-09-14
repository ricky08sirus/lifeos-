const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');


const router = express.Router();
router.use(requireAuth);


router.get('/', async (req, res) => {
  const { from, to, slot } = req.query;
  const meals = await prisma.meal.findMany({
    where: {
      userId: req.userId,
      ...(slot && { slot }),
      ...(from || to ? {
        date: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      } : {}),
    },
    orderBy: { date: 'desc' },
  });
  res.json(meals);
});

router.post('/', async (req, res) => {
  const { date, slot, label, calories, protein, carbs, fat } = req.body;
  if (!date || !slot || !label) {
    return res.status(400).json({ error: 'date, slot, and label are required' });
  }
  const meal = await prisma.meal.create({
    data: { userId: req.userId, date: new Date(date), slot, label, calories, protein, carbs, fat },
  });
  res.status(201).json(meal);
});

router.patch('/:id', async (req, res) => {
  const existing = await prisma.meal.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Meal not found' });
  }
  const { date, slot, label, calories, protein, carbs, fat } = req.body;
  const updated = await prisma.meal.update({
    where: { id: req.params.id },
    data: {
      ...(date !== undefined && { date: new Date(date) }),
      ...(slot !== undefined && { slot }),
      ...(label !== undefined && { label }),
      ...(calories !== undefined && { calories }),
      ...(protein !== undefined && { protein }),
      ...(carbs !== undefined && { carbs }),
      ...(fat !== undefined && { fat }),
    },
  });
  res.json(updated);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.meal.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Meal not found' });
  }
  await prisma.meal.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;




