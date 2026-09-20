import express from 'express';
import { authenticate, optionalAuthenticate } from '../middlewares/authenticate.js';
import mediaController from '../controllers/media.controller.js';

const router = express.Router();

// Media upload and management endpoints
router.post('/upload', optionalAuthenticate, mediaController.uploadMedia);
router.get('/presigned-url', optionalAuthenticate, mediaController.getPresignedUploadUrl);
router.delete('/:key(*)', authenticate, mediaController.deleteMedia);

export default router;
