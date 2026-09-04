const express = require('express');
const multer = require('multer');
const requireAuth = require('../../middleware/auth');
const prisma = require('../../lib/prisma');
const supabase = require('../../lib/supabase');

const router = express.Router();
router.use(requireAuth);

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } }); // 10MB max

router.get('/', async (req, res) => {
  const photos = await prisma.photo.findMany({
    where: { userId: req.userId },
    orderBy: { date: 'desc' },
  });
  res.json(photos);
});

router.post('/', upload.single('photo'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'photo file is required (field name: photo)' });
  const { date } = req.body;
  if (!date) return res.status(400).json({ error: 'date is required' });

  const storagePath = `${req.userId}/photos/${Date.now()}-${req.file.originalname}`;

  const { error: uploadError } = await supabase.storage
    .from('health-uploads')
    .upload(storagePath, req.file.buffer, { contentType: req.file.mimetype });

  if (uploadError) {
    return res.status(500).json({ error: 'Upload failed', details: uploadError.message });
  }

  const { data: signedUrlData } = await supabase.storage
    .from('health-uploads')
    .createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 7-day signed URL

  const photo = await prisma.photo.create({
    data: { userId: req.userId, date: new Date(date), storagePath, url: signedUrlData?.signedUrl || '' },
  });
  res.status(201).json(photo);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.photo.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Photo not found' });
  }
  await supabase.storage.from('health-uploads').remove([existing.storagePath]);
  await prisma.photo.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;