import React, { useEffect, useRef, useState } from 'react';
import { Video, VideoOff, Volume2, VolumeX, Loader2 } from 'lucide-react';
import { getAdminAgoraToken } from '../../services/modules/liveRooms.service';

export function AgoraVideoPlayer({
  roomId,
  hostName,
  hostAvatar,
  coverImage,
  isLive = true,
  roomType = 'live',
}) {
  const containerRef = useRef(null);
  const [hasRemoteVideo, setHasRemoteVideo] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isAudioMuted, setIsAudioMuted] = useState(false);
  const [errorMsg, setErrorMsg] = useState(null);
  const rtcClientRef = useRef(null);
  const remoteAudioTrackRef = useRef(null);

  useEffect(() => {
    if (!roomId || !isLive) {
      setIsLoading(false);
      return;
    }

    let isMounted = true;

    async function initAgora() {
      try {
        setIsLoading(true);
        setErrorMsg(null);

        // 1. Fetch Agora RTC Token for Admin Monitor
        const agoraData = await getAdminAgoraToken(roomId);
        if (!agoraData || !agoraData.token || !agoraData.appId) {
          if (isMounted) {
            setIsLoading(false);
          }
          return;
        }

        // 2. Dynamic import of Agora RTC SDK
        const AgoraRTCModule = await import('agora-rtc-sdk-ng');
        const AgoraRTC = AgoraRTCModule.default || AgoraRTCModule;

        // Turn off Agora verbose logging
        AgoraRTC.setLogLevel(3);

        const client = AgoraRTC.createClient({ mode: 'live', codec: 'vp8' });
        rtcClientRef.current = client;

        await client.setClientRole('audience', { level: 1 });

        client.on('user-published', async (user, mediaType) => {
          try {
            await client.subscribe(user, mediaType);
            if (mediaType === 'video' && user.videoTrack) {
              if (containerRef.current && isMounted) {
                user.videoTrack.play(containerRef.current);
                setHasRemoteVideo(true);
              }
            }
            if (mediaType === 'audio' && user.audioTrack) {
              remoteAudioTrackRef.current = user.audioTrack;
              user.audioTrack.play();
            }
          } catch (subErr) {
            console.warn('[AgoraPlayer] Subscribe error:', subErr);
          }
        });

        client.on('user-unpublished', (user, mediaType) => {
          if (mediaType === 'video') {
            setHasRemoteVideo(false);
          }
          if (mediaType === 'audio' && user.audioTrack) {
            user.audioTrack.stop();
          }
        });

        client.on('user-left', () => {
          setHasRemoteVideo(false);
        });

        const channelName = agoraData.channelName || roomId;
        const uid = agoraData.agoraUid || agoraData.uid || 0;

        await client.join(agoraData.appId, channelName, agoraData.token, uid);

        if (isMounted) {
          setIsLoading(false);
        }
      } catch (err) {
        console.error('[AgoraPlayer] Failed to initialize Agora stream:', err);
        if (isMounted) {
          setErrorMsg('Live stream preview offline');
          setIsLoading(false);
        }
      }
    }

    initAgora();

    return () => {
      isMounted = false;
      if (remoteAudioTrackRef.current) {
        try {
          remoteAudioTrackRef.current.stop();
        } catch (_) {}
      }
      if (rtcClientRef.current) {
        try {
          rtcClientRef.current.leave();
          rtcClientRef.current.removeAllListeners();
        } catch (_) {}
      }
    };
  }, [roomId, isLive]);

  const toggleAudio = () => {
    if (remoteAudioTrackRef.current) {
      if (isAudioMuted) {
        remoteAudioTrackRef.current.setVolume(100);
        setIsAudioMuted(false);
      } else {
        remoteAudioTrackRef.current.setVolume(0);
        setIsAudioMuted(true);
      }
    }
  };

  return (
    <div className="relative w-full h-full flex items-center justify-center overflow-hidden bg-slate-950">
      {/* Real-time Agora Video Track Target Container */}
      <div
        ref={containerRef}
        className={`absolute inset-0 w-full h-full object-cover z-0 transition-opacity duration-500 ${
          hasRemoteVideo ? 'opacity-100' : 'opacity-0 pointer-events-none'
        }`}
      />

      {/* Fallback Display (When audio-only, camera off, or stream loading) */}
      {!hasRemoteVideo && (
        <div className="absolute inset-0 flex flex-col items-center justify-center z-10 p-6 text-center">
          {coverImage ? (
            <img
              src={coverImage}
              alt={hostName}
              className="absolute inset-0 w-full h-full object-cover opacity-35 filter blur-[2px] scale-105"
            />
          ) : (
            <div className="absolute inset-0 bg-gradient-to-br from-indigo-950/60 via-slate-950 to-purple-950/40" />
          )}
          <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/50 to-transparent" />

          {/* Centerpiece Avatar */}
          <div className="relative z-10 flex flex-col items-center">
            <div className="relative mb-3">
              <div className="w-24 h-24 rounded-full border-2 border-amber-400 p-1 shadow-2xl shadow-amber-500/30 bg-slate-900/90 backdrop-blur-md flex items-center justify-center overflow-hidden">
                {hostAvatar ? (
                  <img src={hostAvatar} alt={hostName} className="w-full h-full rounded-full object-cover" />
                ) : (
                  <div className="w-full h-full rounded-full bg-indigo-600 flex items-center justify-center text-2xl font-bold text-white">
                    {(hostName || 'H').charAt(0).toUpperCase()}
                  </div>
                )}
              </div>
            </div>
            <h3 className="text-white font-bold text-lg tracking-wide drop-shadow-md">{hostName}</h3>
            <span className="text-xs text-slate-400 mt-1 flex items-center gap-1">
              {roomType === 'party' ? '🎙️ Voice Party Audio Live' : '📹 Video Stream Waiting for Camera Feed'}
            </span>
          </div>
        </div>
      )}

      {/* Floating Controls & Badges */}
      <div className="absolute bottom-4 right-4 z-20 flex items-center gap-2">
        {hasRemoteVideo && (
          <button
            type="button"
            onClick={toggleAudio}
            className="p-2 rounded-lg bg-black/70 hover:bg-black/90 text-white backdrop-blur-md border border-white/10 transition-colors"
            title={isAudioMuted ? 'Unmute Stream Audio' : 'Mute Stream Audio'}
          >
            {isAudioMuted ? <VolumeX className="h-4 w-4 text-red-400" /> : <Volume2 className="h-4 w-4 text-emerald-400" />}
          </button>
        )}
      </div>

      {isLoading && (
        <div className="absolute top-4 right-4 z-20 flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-black/60 text-slate-300 text-xs backdrop-blur-md border border-white/10">
          <Loader2 className="h-3.5 w-3.5 animate-spin text-amber-400" /> Connecting Stream...
        </div>
      )}

      {hasRemoteVideo && (
        <div className="absolute top-4 right-4 z-20 flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-emerald-500/20 text-emerald-400 text-xs backdrop-blur-md border border-emerald-500/30">
          <Video className="h-3.5 w-3.5" /> Video Feed Active
        </div>
      )}
    </div>
  );
}

export default AgoraVideoPlayer;
