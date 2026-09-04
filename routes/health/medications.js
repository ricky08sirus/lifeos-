const express = require('express');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');


const router = express.Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const medications = await prisma.medication.findMany({
    where: { userId: req.userId },
    orderBy: { createdAt: 'desc' },
  });
  res.json(medications);
});


router.post('/', async (req, res) => {
  const { name, isPrescription, dosage, frequency, quantityLeft, refillOn } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });

  const medication = await prisma.medication.create({
    data: {
      userId: req.userId,
      name,
      isPrescription: !!isPrescription,
      dosage,
      frequency,
      quantityLeft,
      refillOn: refillOn ? new Date(refillOn) : undefined,
    },
  });
  res.status(201).json(medication);
});



router.patch('/:id', async (req, res) => {
  const existing = await prisma.medication.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Medication not found' });
  }
  const { name, isPrescription, dosage, frequency, quantityLeft, refillOn } = req.body;
  const updated = await prisma.medication.update({
    where: { id: req.params.id },
    data: {
      ...(name !== undefined && { name }),
      ...(isPrescription !== undefined && { isPrescription }),
      ...(dosage !== undefined && { dosage }),
      ...(frequency !== undefined && { frequency }),
      ...(quantityLeft !== undefined && { quantityLeft }),
      ...(refillOn !== undefined && { refillOn: new Date(refillOn) }),
    },
  });
  res.json(updated);
});


router.delete('/:id', async (req, res) => {
  const existing = await prisma.medication.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Medication not found' });
  }
  await prisma.medication.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;


