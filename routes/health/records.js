const express = require('express');
const multer = require('multer');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');
const supabase = require('../../lib/supabase');

const router = express.Router();
router.use(requireAuth);

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } }); // 20MB max

router.get('/', async (req, res) => {
  const records = await prisma.medicalRecord.findMany({
    where: { userId: req.userId },
    orderBy: { createdAt: 'desc' },
  });
  res.json(records);
});

router.post('/', upload.single('record'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'record file is required (field name: record)' });
  const { title } = req.body;
  if (!title) return res.status(400).json({ error: 'title is required' });

  const storagePath = `${req.userId}/records/${Date.now()}-${req.file.originalname}`;

  const { error: uploadError } = await supabase.storage
    .from('health-uploads')
    .upload(storagePath, req.file.buffer, { contentType: req.file.mimetype });

  if (uploadError) {
    return res.status(500).json({ error: 'Upload failed', details: uploadError.message });
  }

  const { data: signedUrlData } = await supabase.storage
    .from('health-uploads')
    .createSignedUrl(storagePath, 60 * 60 * 24 * 7);

  const record = await prisma.medicalRecord.create({
    data: { userId: req.userId, title, storagePath, url: signedUrlData?.signedUrl || '' },
  });
  res.status(201).json(record);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.medicalRecord.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Medical record not found' });
  }
  await supabase.storage.from('health-uploads').remove([existing.storagePath]);
  await prisma.medicalRecord.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;