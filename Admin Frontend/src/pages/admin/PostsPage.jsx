// ============================================================
// ZeParty Admin Portal — Posts & Content Management Page (JSX)
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  MessageSquare,
  Search,
  Filter,
  Eye,
  Trash2,
  Heart,
  Share2,
  AlertTriangle,
  Play,
  Film,
  Image as ImageIcon,
  FileText,
  RefreshCw,
  ExternalLink,
  ShieldAlert,
  User,
  CheckCircle2,
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { Modal } from '../../components/ui/Modal';
import { Toast } from '../../components/ui/Toast';
import { ImageViewerModal } from '../../components/ui/ImageViewerModal';
import { getUserPosts, deleteUserPost } from '../../services/modules/posts.service';
import { formatDistanceToNow } from '../../utils/formatters';

export function PostsPage() {
  const navigate = useNavigate();

  const [posts, setPosts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [contentTypeFilter, setContentTypeFilter] = useState('ALL'); // 'ALL' | 'VIDEO' | 'IMAGE' | 'TEXT'
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [toast, setToast] = useState(null);

  // Pagination
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(12);

  // Modals
  const [postToDelete, setPostToDelete] = useState(null);
  const [deleteReason, setDeleteReason] = useState('');
  const [isDeleting, setIsDeleting] = useState(false);
  const [previewImage, setPreviewImage] = useState(null);

  function showToast(message, type = 'success', title = '') {
    setToast({
      message,
      type,
      title: title || (type === 'success' ? 'Action Completed' : 'Operation Failed'),
      duration: 4500,
    });
  }

  const loadPosts = async () => {
    setIsLoading(true);
    setError('');
    try {
      const data = await getUserPosts(null, { page, limit });
      setPosts(data || []);
    } catch (err) {
      console.error('Failed to load posts:', err);
      setError(err.message || 'Failed to retrieve posts from server.');
      setPosts([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadPosts();
  }, [page, limit]);

  // Filter posts
  const filteredPosts = useMemo(() => {
    return posts.filter((p) => {
      const matchSearch =
        !search.trim() ||
        p.content?.toLowerCase().includes(search.toLowerCase()) ||
        p.author?.username?.toLowerCase().includes(search.toLowerCase()) ||
        p.id?.toLowerCase().includes(search.toLowerCase());

      const isVideo = p.mediaUrl?.match(/\.(mp4|mov|webm|avi|mkv)$/i) || p.type === 'SHORT' || p.type === 'VIDEO';
      const isImage = (p.mediaUrl?.match(/\.(jpg|jpeg|png|webp|gif)$/i) || p.mediaUrls?.length > 0) && !isVideo;
      const isText = !p.mediaUrl && (!p.mediaUrls || p.mediaUrls.length === 0);

      let matchType = true;
      if (contentTypeFilter === 'VIDEO') matchType = isVideo;
      else if (contentTypeFilter === 'IMAGE') matchType = isImage;
      else if (contentTypeFilter === 'TEXT') matchType = isText;

      const matchStatus = statusFilter === 'ALL' || (p.status || 'ACTIVE').toUpperCase() === statusFilter;

      return matchSearch && matchType && matchStatus;
    });
  }, [posts, search, contentTypeFilter, statusFilter]);

  // Delete / Moderate Post Handler
  const handleDeletePost = async () => {
    if (!postToDelete) return;
    setIsDeleting(true);
    try {
      await deleteUserPost(postToDelete.id, deleteReason.trim() || 'Violated platform safety guidelines');
      showToast('Post removed and deleted successfully from public feeds.', 'success', 'Post Deleted');
      setPostToDelete(null);
      setDeleteReason('');
      await loadPosts();
    } catch (err) {
      showToast(err.message || 'Failed to delete post.', 'error', 'Deletion Error');
    } finally {
      setIsDeleting(false);
    }
  };

  const videoCount = posts.filter((p) => p.mediaUrl?.match(/\.(mp4|mov|webm|avi)$/i) || p.type === 'SHORT').length;
  const imageCount = posts.filter((p) => p.mediaUrl?.match(/\.(jpg|jpeg|png|webp|gif)$/i)).length;

  return (
    <div className="flex flex-col gap-6">
      {/* Toast Notification */}
      <Toast toast={toast} onClose={() => setToast(null)} />

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2.5">
            <MessageSquare className="h-6 w-6 text-gold-400" />
            Posts & Dynamics Moderation
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Real-time feed for reviewing, inspecting media, and moderating user-published posts, videos, and shorts.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={loadPosts}
            isLoading={isLoading}
            className="flex items-center gap-1.5"
          >
            <RefreshCw className="h-4 w-4" /> Refresh Posts
          </Button>
        </div>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <Card className="p-4 text-center">
          <p className="text-2xl font-bold text-white">{posts.length}</p>
          <p className="text-xs text-slate-400 mt-0.5">Loaded Posts</p>
        </Card>
        <Card className="p-4 text-center">
          <p className="text-2xl font-bold text-purple-400">{videoCount}</p>
          <p className="text-xs text-slate-400 mt-0.5">Videos & Shorts</p>
        </Card>
        <Card className="p-4 text-center">
          <p className="text-2xl font-bold text-sky-400">{imageCount}</p>
          <p className="text-xs text-slate-400 mt-0.5">Photos & Images</p>
        </Card>
        <Card className="p-4 text-center">
          <p className="text-2xl font-bold text-emerald-400">
            {posts.filter((p) => (p.status || 'ACTIVE') === 'ACTIVE').length}
          </p>
          <p className="text-xs text-slate-400 mt-0.5">Active Published</p>
        </Card>
      </div>

      {/* Search and Filters */}
      <Card className="p-4 flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <Input
          placeholder="Search by caption text, author @username, or Post ID…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1 max-w-md w-full min-w-0"
        />

        <div className="flex items-center gap-2 flex-wrap">
          {/* Content Type Filter */}
          <div className="flex rounded-lg bg-slate-900 p-1 border border-slate-700">
            {[
              { id: 'ALL', label: 'All Content' },
              { id: 'VIDEO', label: 'Videos' },
              { id: 'IMAGE', label: 'Images' },
              { id: 'TEXT', label: 'Text Only' },
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setContentTypeFilter(tab.id)}
                className={[
                  'px-3 py-1 rounded text-xs font-medium transition-colors',
                  contentTypeFilter === tab.id
                    ? 'bg-gold-500 text-slate-950 font-bold'
                    : 'text-slate-400 hover:text-white',
                ].join(' ')}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Status Filter */}
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="h-8 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs px-2.5 focus:outline-none focus:border-indigo-500"
          >
            <option value="ALL">All Statuses</option>
            <option value="ACTIVE">Active</option>
            <option value="HIDDEN">Hidden</option>
            <option value="FLAGGED">Flagged</option>
          </select>
        </div>
      </Card>

      {/* Error state */}
      {error && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 flex items-center justify-between">
          <div className="text-sm">
            <span className="font-semibold">Error loading posts: </span>
            {error}
          </div>
          <Button variant="outline" size="sm" onClick={loadPosts}>
            Retry
          </Button>
        </div>
      )}

      {/* Posts Cards Grid */}
      {isLoading ? (
        <div className="p-16 text-center text-slate-400 bg-slate-900/40 rounded-2xl border border-slate-800">
          <RefreshCw className="h-8 w-8 text-indigo-400 animate-spin mx-auto mb-3" />
          <p className="text-sm font-medium text-slate-300">Loading platform posts and dynamics...</p>
        </div>
      ) : filteredPosts.length === 0 ? (
        <div className="p-16 text-center text-slate-400 bg-slate-900/40 rounded-2xl border border-slate-800">
          <FileText className="h-12 w-12 text-slate-600 mx-auto mb-3" />
          <p className="text-base font-semibold text-slate-300">No Posts Found</p>
          <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
            No published dynamics match your search criteria. Try modifying your filter settings.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
          {filteredPosts.map((post) => {
            const isVideo = post.mediaUrl?.match(/\.(mp4|mov|webm|avi)$/i) || post.type === 'SHORT';
            return (
              <Card
                key={post.id}
                className="p-5 flex flex-col justify-between space-y-4 hover:border-slate-600 transition-all shadow-md bg-slate-900/70"
              >
                {/* Author Info & Actions */}
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-3 min-w-0">
                    {post.author?.avatarUrl ? (
                      <img
                        src={post.author.avatarUrl}
                        alt={post.author.username}
                        onClick={() =>
                          setPreviewImage({
                            url: post.author.avatarUrl,
                            title: `@${post.author.username}'s Avatar`,
                          })
                        }
                        className="h-10 w-10 rounded-full object-cover ring-1 ring-slate-700 shrink-0 cursor-pointer hover:ring-gold-400 transition-all"
                      />
                    ) : (
                      <div className="h-10 w-10 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-xs font-bold shrink-0">
                        {(post.author?.username || 'U').charAt(0).toUpperCase()}
                      </div>
                    )}
                    <div className="min-w-0">
                      <p
                        onClick={() => post.userId && navigate(`/admin/users/${post.userId}`)}
                        className="font-semibold text-white text-sm hover:text-gold-400 cursor-pointer truncate"
                      >
                        {post.author?.displayName || post.author?.username || 'User'}
                      </p>
                      <p className="text-xs text-indigo-400 font-mono">@{post.author?.username || post.userId?.slice(0, 8)}</p>
                    </div>
                  </div>

                  <div className="flex items-center gap-1.5 shrink-0">
                    <StatusBadge status={(post.status || 'ACTIVE').toLowerCase()} />
                    {isVideo && (
                      <Badge variant="purple" className="flex items-center gap-1">
                        <Film className="h-3 w-3" /> Video
                      </Badge>
                    )}
                  </div>
                </div>

                {/* Content Text */}
                {post.content && (
                  <p className="text-xs text-slate-200 line-clamp-3 leading-relaxed break-words bg-slate-950/40 p-2.5 rounded-lg border border-slate-800/60">
                    {post.content}
                  </p>
                )}

                {/* Media Preview */}
                {post.mediaUrl && (
                  <div className="relative rounded-xl overflow-hidden bg-black/60 border border-slate-800 group">
                    {isVideo ? (
                      <video
                        src={post.mediaUrl}
                        controls
                        className="w-full max-h-56 object-cover bg-black"
                        preload="metadata"
                      />
                    ) : (
                      <div
                        onClick={() =>
                          setPreviewImage({
                            url: post.mediaUrl,
                            title: `Post Media (${post.id})`,
                          })
                        }
                        className="cursor-pointer"
                      >
                        <img
                          src={post.mediaUrl}
                          alt="Post attachment"
                          className="w-full h-48 object-cover group-hover:scale-105 transition-transform duration-200"
                        />
                        <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity text-white text-xs font-medium gap-1">
                          <Eye className="h-4 w-4" /> Click to view full image
                        </div>
                      </div>
                    )}
                  </div>
                )}

                {/* Post Footer & Moderation Button */}
                <div className="pt-2 border-t border-slate-800/80 space-y-3">
                  <div className="flex items-center justify-between text-xs text-slate-400">
                    <div className="flex items-center gap-3">
                      <span className="flex items-center gap-1 text-rose-400 font-mono">
                        <Heart className="h-3.5 w-3.5" /> {post.likesCount || 0}
                      </span>
                      <span className="flex items-center gap-1 text-sky-400 font-mono">
                        <MessageSquare className="h-3.5 w-3.5" /> {post.commentsCount || 0}
                      </span>
                      <span className="flex items-center gap-1 text-emerald-400 font-mono">
                        <Share2 className="h-3.5 w-3.5" /> {post.sharesCount || 0}
                      </span>
                    </div>
                    <span className="text-[11px] text-slate-500 font-mono">
                      {formatDistanceToNow(post.createdAt)}
                    </span>
                  </div>

                  <div className="flex items-center justify-between gap-2">
                    <Button
                      variant="ghost"
                      size="xs"
                      onClick={() => post.userId && navigate(`/admin/users/${post.userId}`)}
                      className="text-slate-400 hover:text-white"
                    >
                      <User className="h-3.5 w-3.5 mr-1" /> View User Profile
                    </Button>
                    <Button
                      variant="danger"
                      size="xs"
                      onClick={() => setPostToDelete(post)}
                      className="flex items-center gap-1"
                    >
                      <Trash2 className="h-3.5 w-3.5" /> Moderate / Delete
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {postToDelete && (
        <Modal
          isOpen={true}
          onClose={() => setPostToDelete(null)}
          title="Moderate / Delete Post"
          description={`Permanently remove post #${postToDelete.id} from public feed.`}
          size="sm"
        >
          <div className="flex flex-col gap-4">
            <div className="p-3.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs flex items-start gap-2.5">
              <AlertTriangle className="h-4 w-4 shrink-0 mt-0.5 text-red-400" />
              <div>
                <p className="font-semibold text-red-300">Content Moderation</p>
                <p className="mt-0.5 text-red-400/90 leading-relaxed">
                  Deleting this post will immediately hide it from all users and record an entry in the administrative audit log.
                </p>
              </div>
            </div>

            {postToDelete.content && (
              <div className="p-2.5 rounded-lg bg-slate-900 border border-slate-800 text-xs text-slate-300 italic">
                "{postToDelete.content}"
              </div>
            )}

            <Input
              label="Moderation Reason (Optional)"
              value={deleteReason}
              onChange={(e) => setDeleteReason(e.target.value)}
              placeholder="e.g. Terms violation, inappropriate content (optional)..."
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="ghost" size="sm" onClick={() => setPostToDelete(null)} disabled={isDeleting}>
                Cancel
              </Button>
              <Button
                type="button"
                variant="danger"
                size="sm"
                isLoading={isDeleting}
                onClick={handleDeletePost}
                disabled={isDeleting}
              >
                Delete Post
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Image Preview Modal */}
      {previewImage && (
        <ImageViewerModal
          isOpen={true}
          onClose={() => setPreviewImage(null)}
          imageUrl={previewImage.url}
          title={previewImage.title}
        />
      )}
    </div>
  );
}

export default PostsPage;
