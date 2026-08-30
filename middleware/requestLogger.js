const crypto = require('crypto');
const logger = require('../lib/logger');
const { incrementHitCount } = require('../lib/stats');

// Fields to hide from logs even though they're in the request body
const SENSITIVE_FIELDS = ['password', 'passwordHash', 'token', 'accessToken', 'refreshToken'];

function sanitize(body) {
  if (!body || typeof body !== 'object') return body;
  const clean = { ...body };
  for (const field of SENSITIVE_FIELDS) {
    if (clean[field] !== undefined) clean[field] = '[REDACTED]';
  }
  return clean;
}

function requestLogger(req, res, next) {
  const requestId = crypto.randomUUID();
  req.requestId = requestId;

  const start = Date.now();

  logger.info('Incoming request', {
    requestId,
    method: req.method,
    path: req.originalUrl,
    ip: req.ip,
    userAgent: req.headers['user-agent'],
    body: sanitize(req.body),
  });

  // Track this endpoint being hit (method + route path, not the raw URL, so /users/123 and /users/456 count as one)
  incrementHitCount(req.method, req.route ? req.baseUrl + req.route.path : req.originalUrl);

  // Hook into the response finishing to log the outcome
  res.on('finish', () => {
    const durationMs = Date.now() - start;
    const logLevel = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';

    logger[logLevel]('Request completed', {
      requestId,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs,
      userId: req.userId || null,
    });
  });

  next();
}

module.exports = requestLogger;