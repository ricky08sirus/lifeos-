const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');

const router = express.Router({ mergeParams: true });
router.use(requireAuth);

async function getOwnedHabit(habitId, userId) {
  const habit = await prisma.habit.findUnique({ where: { id: habitId } });
  if (!habit || habit.userId !== userId) return null;
  return habit;
}

// GET /habits/:id/logs?from=...&to=...
router.get('/', async (req, res) => {
  const habit = await getOwnedHabit(req.params.id, req.userId);
  if (!habit) return res.status(404).json({ error: 'Habit not found' });

  const { from, to } = req.query;
  const logs = await prisma.habitLog.findMany({
    where: {
      habitId: habit.id,
      ...(from || to ? {
        date: {
          ...(from && { gte: new Date(from) }),
          ...(to && { lte: new Date(to) }),
        },
      } : {}),
    },
    orderBy: { date: 'desc' },
  });
  res.json(logs);
});

// PUT /habits/:id/logs/:date - overwrite, since a date can only have one log (see @@unique in schema)
router.put('/:date', async (req, res) => {
  const habit = await getOwnedHabit(req.params.id, req.userId);
  if (!habit) return res.status(404).json({ error: 'Habit not found' });

  const { status, value } = req.body;
  if (!status) return res.status(400).json({ error: 'status is required (done | skipped)' });

  const date = new Date(req.params.date);
  const log = await prisma.habitLog.upsert({
    where: { habitId_date: { habitId: habit.id, date } },
    update: { status, value },
    create: { habitId: habit.id, date, status, value },
  });
  res.json(log);
});

// DELETE /habits/:id/logs/:date - clears back to "unlogged"
router.delete('/:date', async (req, res) => {
  const habit = await getOwnedHabit(req.params.id, req.userId);
  if (!habit) return res.status(404).json({ error: 'Habit not found' });

  const date = new Date(req.params.date);
  await prisma.habitLog.deleteMany({ where: { habitId: habit.id, date } });
  res.status(204).send();
});

module.exports = router;