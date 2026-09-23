// ============================================================
// ZeParty Admin Portal — Image Viewer Modal Component (JSX)
// ============================================================

import React from 'react';
import { X, Download, ExternalLink, ZoomIn } from 'lucide-react';
import { Modal } from './Modal';
import { Button } from './Button';

export function ImageViewerModal({ isOpen, onClose, imageUrl, title = 'Media Preview', subtitle = '', isVideo: isVideoProp }) {
  if (!isOpen || !imageUrl) return null;

  const isVideo = isVideoProp || typeof imageUrl === 'string' && (
    imageUrl.match(/\.(mp4|webm|mov|m4v|ogg)(\?.*)?$/i) || imageUrl.includes('video')
  );

  const handleDownload = () => {
    const a = document.createElement('a');
    a.href = imageUrl;
    a.download = title.replace(/\s+/g, '_').toLowerCase() + (isVideo ? '.mp4' : '.jpg');
    a.target = '_blank';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      description={subtitle || (isVideo ? 'High-definition video preview' : 'Full resolution image view')}
      size="md"
    >
      <div className="flex flex-col items-center gap-4">
        <div className="relative w-full max-h-[70vh] flex items-center justify-center overflow-hidden rounded-xl bg-slate-950 border border-slate-800 p-2">
          {isVideo ? (
            <video
              src={imageUrl}
              controls
              autoPlay
              className="max-h-[60vh] max-w-full rounded-lg object-contain bg-black shadow-2xl"
            />
          ) : (
            <img
              src={imageUrl}
              alt={title}
              className="max-h-[60vh] max-w-full rounded-lg object-contain shadow-2xl transition-transform duration-200 hover:scale-105"
              onError={(e) => {
                e.target.src = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60';
              }}
            />
          )}
        </div>

        <div className="flex items-center justify-between w-full pt-2 border-t border-slate-800">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => window.open(imageUrl, '_blank')}
            className="flex items-center gap-1.5 text-xs text-indigo-400 hover:text-indigo-300"
          >
            <ExternalLink className="h-4 w-4" /> Open in New Tab
          </Button>

          <div className="flex items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={handleDownload}
              className="flex items-center gap-1.5 text-xs"
            >
              <Download className="h-4 w-4" /> Download Image
            </Button>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={onClose}
              className="text-xs"
            >
              Close
            </Button>
          </div>
        </div>
      </div>
    </Modal>
  );
}

export default ImageViewerModal;
