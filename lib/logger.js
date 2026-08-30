const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');

const logger = winston.createLogger({
  level: process.env.NODE_ENV === 'production' ? 'info' : 'debug',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    // Console output while developing — colored, human-readable
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),

    // All logs (info, warn, error, debug) — auto-deletes anything older than 15 days
    new DailyRotateFile({
      filename: 'logs/combined-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxFiles: '15d',       // <-- this is the auto-cleanup: keeps only the last 15 days
      zippedArchive: true,   // compresses old logs (.gz) so they take even less space
    }),

    // Errors only — same 15-day cleanup, kept separate so you can scan just failures
    new DailyRotateFile({
      filename: 'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      level: 'error',
      maxFiles: '15d',
      zippedArchive: true,
    }),
  ],
});

module.exports = logger;