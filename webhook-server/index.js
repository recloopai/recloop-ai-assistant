import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import { ConvexHttpClient } from 'convex/browser';
import { api } from '../backend/convex/_generated/api.js';
import { gmailWebhookHandler } from './handlers/gmailHandler.js';
import { healthHandler } from './handlers/healthHandler.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

// Initialize Convex client
const convex = new ConvexHttpClient(process.env.CONVEX_URL);

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || 'https://recloop.com',
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/webhook', limiter);

// Logging
app.use(morgan('combined'));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', healthHandler);
app.get('/webhook/health', healthHandler);

// Gmail webhook endpoint
app.post('/webhook/gmail', async (req, res) => {
  try {
    await gmailWebhookHandler(req, res, convex);
  } catch (error) {
    console.error('Gmail webhook error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Generic webhook endpoint for future integrations
app.post('/webhook/:service', async (req, res) => {
  const { service } = req.params;
  
  console.log(`Received webhook for service: ${service}`);
  console.log('Headers:', req.headers);
  console.log('Body:', req.body);
  
  // Log to Convex
  try {
    await convex.mutation(api.webhooks.logWebhook, {
      source: service,
      payload: JSON.stringify(req.body),
      status: 'success'
    });
  } catch (error) {
    console.error('Failed to log webhook:', error);
  }
  
  res.json({ received: true, service, timestamp: new Date().toISOString() });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Server error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Endpoint not found',
    path: req.path,
    method: req.method
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 ReCloop Webhook Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📧 Gmail webhook: http://localhost:${PORT}/webhook/gmail`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});