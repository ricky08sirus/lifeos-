const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { z } = require('zod');
const prisma = require('../lib/prisma');

const router = express.Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

function issueTokens(userId) {
  const accessToken = jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '15m' });
  const refreshToken = crypto.randomBytes(40).toString('hex');
  return { accessToken, refreshToken };
}

async function storeRefreshToken(userId, refreshToken) {
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
  await prisma.refreshToken.create({
    data: { token: refreshToken, userId, expiresAt },
  });
}

router.post('/register', async (req, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.issues[0].message });
  }
  const { email, password } = parsed.data;

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    return res.status(409).json({ error: 'Email already registered' });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({ data: { email, passwordHash } });

  const { accessToken, refreshToken } = issueTokens(user.id);
  await storeRefreshToken(user.id, refreshToken);

  res.status(201).json({
    accessToken,
    refreshToken,
    user: { id: user.id, email: user.email },
  });
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password required' });
  }

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) return res.status(401).json({ error: 'Invalid email or password' });

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) return res.status(401).json({ error: 'Invalid email or password' });

  const { accessToken, refreshToken } = issueTokens(user.id);
  await storeRefreshToken(user.id, refreshToken);

  res.json({
    accessToken,
    refreshToken,
    user: { id: user.id, email: user.email },
  });
});

router.post('/logout', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ error: 'refreshToken required' });
  }

  await prisma.refreshToken.deleteMany({ where: { token: refreshToken } });
  res.json({ message: 'Logged out' });
});

router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ error: 'refreshToken required' });
  }

  const stored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
  if (!stored || stored.expiresAt < new Date()) {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }

  const accessToken = jwt.sign({ userId: stored.userId }, process.env.JWT_SECRET, { expiresIn: '15m' });
  res.json({ accessToken });
});

router.post('/password-reset', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'email required' });

  const user = await prisma.user.findUnique({ where: { email } });
  // Always respond the same way whether or not the user exists — don't leak which emails are registered
  if (!user) {
    return res.json({ message: 'If that email is registered, a reset link has been sent.' });
  }

  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

  await prisma.passwordResetToken.create({
    data: { token, userId: user.id, expiresAt },
  });

  // TODO: integrate a real email service (e.g. Resend, SendGrid) to actually send this token.
  // For now, returning it directly so you can test the flow end-to-end.
  res.json({ message: 'Reset token generated (email sending not yet integrated)', resetToken: token });
});

module.exports = router;