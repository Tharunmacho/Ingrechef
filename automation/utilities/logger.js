const winston = require('winston');
const path = require('path');
const fs = require('fs');

const logDir = path.join(__dirname, '..', 'logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'appium-e2e' },
  transports: [
    new winston.transports.File({ 
      filename: path.join(logDir, 'error.log'), 
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5
    }),
    new winston.transports.File({ 
      filename: path.join(logDir, 'appium.log'),
      maxsize: 10485760, // 10MB
      maxFiles: 5
    })
  ]
});

// Always output to console for clean test runs
logger.add(new winston.transports.Console({
  format: winston.format.combine(
    winston.format.colorize(),
    winston.format.printf(({ level, message, timestamp, ...metadata }) => {
      let msg = `[${timestamp}] ${level}: ${message}`;
      // Remove default metadata keys if they are empty or just service name
      if (metadata.service === 'appium-e2e') {
        delete metadata.service;
      }
      if (Object.keys(metadata).length > 0) {
        msg += ` | ${JSON.stringify(metadata)}`;
      }
      return msg;
    })
  )
}));

module.exports = logger;
