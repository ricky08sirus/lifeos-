const { PrismaClient } = require('@prisma/client');
const logger = require('./logger');

const basePrisma = new PrismaClient();

const prisma = basePrisma.$extends({
  query: {
    async $allOperations({ model, operation, args, query }) {
      const start = Date.now();
      const result = await query(args);
      const durationMs = Date.now() - start;

      logger.debug('Database operation', {
        model,
        action: operation,
        durationMs,
      });

      return result;
    },
  },
});

module.exports = prisma;