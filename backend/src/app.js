import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import env from './config/env.js';
import apiRoutes from './routes/index.js';

const app = express();

// Security HTTP headers
app.use(helmet());

// CORS configuration
app.use(
  cors({
    origin: env.NODE_ENV === 'production' ? env.CORS_ORIGIN : '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

// Request body parsers with limits
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Pino request logger
app.use(
  pinoHttp({
    level: env.NODE_ENV === 'development' ? 'debug' : 'info',
    redact: {
      paths: ['req.headers.authorization', 'body.password', 'body.token', 'body.otp'],
      censor: '***',
    },
  })
);

// Register routes
app.use('/api', apiRoutes);

// Global 404 handler
app.use((req, res, next) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
    error: {
      code: 'ROUTE_NOT_FOUND',
    },
  });
});

// Centralized error handler middleware
app.use((err, req, res, next) => {
  req.log.error(err);

  if (err.name === 'ZodError') {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      error: {
        code: 'VALIDATION_ERROR',
        details: err.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      },
    });
  }

  const status = err.status || 500;
  const message = err.message || 'Internal Server Error';

  res.status(status).json({
    success: false,
    message,
    error: {
      code: err.code || 'INTERNAL_SERVER_ERROR',
      ...(env.NODE_ENV === 'development' ? { stack: err.stack } : {}),
    },
  });
});

export default app;
