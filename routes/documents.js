const express = require('express');
const multer = require('multer');
const requireAuth = require('../middleware/auth');
const prisma = require('../lib/prisma');
const supabase = require('../lib/supabase');

const router = express.Router();
router.use(requireAuth);

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });

// GET /documents?linkedType=health
router.get('/', async (req, res) => {
  const { linkedType } = req.query;
  const documents = await prisma.document.findMany({
    where: { userId: req.userId, ...(linkedType && { linkedType }) },
    orderBy: { createdAt: 'desc' },
  });
  res.json(documents);
});

router.post('/', upload.single('document'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'document file is required (field name: document)' });
  const { title, linkedType, linkedId } = req.body;
  if (!title) return res.status(400).json({ error: 'title is required' });

  const storagePath = `${req.userId}/documents/${Date.now()}-${req.file.originalname}`;
  const { error: uploadError } = await supabase.storage
    .from('health-uploads')
    .upload(storagePath, req.file.buffer, { contentType: req.file.mimetype });
  if (uploadError) return res.status(500).json({ error: 'Upload failed', details: uploadError.message });

  const { data: signedUrlData } = await supabase.storage
    .from('health-uploads')
    .createSignedUrl(storagePath, 60 * 60 * 24 * 7);

  const document = await prisma.document.create({
    data: { userId: req.userId, title, linkedType, linkedId, storagePath, url: signedUrlData?.signedUrl || '' },
  });
  res.status(201).json(document);
});

router.get('/:id', async (req, res) => {
  const document = await prisma.document.findUnique({ where: { id: req.params.id } });
  if (!document || document.userId !== req.userId) {
    return res.status(404).json({ error: 'Document not found' });
  }
  res.json(document);
});

router.delete('/:id', async (req, res) => {
  const existing = await prisma.document.findUnique({ where: { id: req.params.id } });
  if (!existing || existing.userId !== req.userId) {
    return res.status(404).json({ error: 'Document not found' });
  }
  await supabase.storage.from('health-uploads').remove([existing.storagePath]);
  await prisma.document.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;