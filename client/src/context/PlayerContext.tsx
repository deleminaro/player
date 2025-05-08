import React, { createContext, useState, useEffect, useRef, useCallback } from "react";
import { Howl } from "howler";
import { SoundCloudTrack } from "@shared/schema";
import { soundCloudClient } from "../lib/soundcloud";
import { useToast } from "@/hooks/use-toast";

// Define the context type
interface PlayerContextType {
  currentTrack: SoundCloudTrack | null;
  playlist: SoundCloudTrack[];
  isPlaying: boolean;
  volume: number;
  isMuted: boolean;
  progress: number;
  duration: number;
  repeatMode: number; // 0: no repeat, 1: repeat all, 2: repeat one
  playTrack: (track: SoundCloudTrack) => Promise<void>;
  playTrackById: (id: number) => Promise<void>;
  pauseTrack: () => void;
  resumeTrack: () => void;
  togglePlay: () => void;
  nextTrack: () => void;
  previousTrack: () => void;
  seekPosition: (position: number) => void;
  setVolume: (volume: number) => void;
  toggleMute: () => void;
  toggleRepeat: () => void;
  addToPlaylist: (track: SoundCloudTrack) => void;
  removeFromPlaylist: (trackId: number) => void;
  clearPlaylist: () => void;
}

// Create the context with an initial undefined value
export const PlayerContext = createContext<PlayerContextType | undefined>(undefined);

// Provider component
export const PlayerProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currentTrack, setCurrentTrack] = useState<SoundCloudTrack | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [volume, setVolume] = useState(70);
  const [isMuted, setIsMuted] = useState(false);
  const [progress, setProgress] = useState(0);
  const [duration, setDuration] = useState(0);
  const [repeatMode, setRepeatMode] = useState(0);
  const [playlist, setPlaylist] = useState<SoundCloudTrack[]>([]);
  
  const sound = useRef<Howl | null>(null);
  const progressInterval = useRef<number | null>(null);
  const { toast } = useToast();

  // Cleanup function for interval
  const clearProgressInterval = useCallback(() => {
    if (progressInterval.current) {
      window.clearInterval(progressInterval.current);
      progressInterval.current = null;
    }
  }, []);

  // Update progress on interval
  const startProgressInterval = useCallback(() => {
    clearProgressInterval();
    
    progressInterval.current = window.setInterval(() => {
      if (sound.current && sound.current.playing()) {
        const currentTime = sound.current.seek();
        setProgress(typeof currentTime === 'number' ? currentTime : 0);
      }
    }, 500);
  }, [clearProgressInterval]);

  // Stop current playback and clean up
  const stopCurrentSound = useCallback(() => {
    if (sound.current) {
      sound.current.stop();
      sound.current.unload();
      sound.current = null;
    }
    setIsPlaying(false);
    clearProgressInterval();
  }, [clearProgressInterval]);

  // Load and play a track
  const playTrack = useCallback(async (track: SoundCloudTrack) => {
    try {
      stopCurrentSound();
      
      // Record this track in history
      try {
        await fetch('/api/history', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            soundcloud_id: track.id,
            title: track.title,
            artist: track.user.username,
            artwork_url: track.artwork_url,
            duration: track.duration,
            permalink_url: track.permalink_url,
            playback_count: track.playback_count,
          }),
        });
      } catch (error) {
        console.error('Failed to record history:', error);
      }

      // Get stream URL
      const streamUrl = await soundCloudClient.getStreamUrl(track);
      
      // Create Howl instance
      sound.current = new Howl({
        src: [streamUrl],
        html5: true,
        volume: volume / 100,
        onplay: () => {
          setIsPlaying(true);
          startProgressInterval();
        },
        onload: () => {
          setDuration(sound.current?.duration() || 0);
        },
        onend: () => {
          if (repeatMode === 2) {
            // Repeat one
            sound.current?.play();
          } else if (repeatMode === 1) {
            // Repeat all - go to next track or back to first track
            nextTrack();
          } else {
            // No repeat - stop after current track ends
            setIsPlaying(false);
            clearProgressInterval();
          }
        },
        onpause: () => {
          setIsPlaying(false);
          clearProgressInterval();
        },
        onstop: () => {
          setIsPlaying(false);
          clearProgressInterval();
        },
        onseek: () => {
          // Update progress immediately on seek
          if (sound.current) {
            setProgress(sound.current.seek() as number);
          }
        },
      });
      
      setCurrentTrack(track);
      sound.current.play();
    } catch (error) {
      console.error('Failed to play track:', error);
      toast({
        title: "Playback Error",
        description: "Failed to play track. Please try another one.",
        variant: "destructive",
      });
    }
  }, [volume, repeatMode, stopCurrentSound, startProgressInterval, clearProgressInterval, toast]);

  // Play track by ID
  const playTrackById = useCallback(async (id: number) => {
    try {
      const track = await soundCloudClient.getTrack(id);
      await playTrack(track);
    } catch (error) {
      console.error('Failed to get track by ID:', error);
      toast({
        title: "Track Not Found",
        description: "The requested track could not be loaded.",
        variant: "destructive",
      });
    }
  }, [playTrack, toast]);

  // Pause current track
  const pauseTrack = useCallback(() => {
    if (sound.current) {
      sound.current.pause();
    }
  }, []);

  // Resume playback
  const resumeTrack = useCallback(() => {
    if (sound.current) {
      sound.current.play();
    }
  }, []);

  // Toggle play/pause
  const togglePlay = useCallback(() => {
    if (!sound.current) return;
    
    if (isPlaying) {
      pauseTrack();
    } else {
      resumeTrack();
    }
  }, [isPlaying, pauseTrack, resumeTrack]);

  // Seek to position (0-1)
  const seekPosition = useCallback((position: number) => {
    if (!sound.current || !duration) return;
    
    const seekTime = Math.max(0, Math.min(position * duration, duration));
    sound.current.seek(seekTime);
    setProgress(seekTime);
  }, [duration]);

  // Set volume (0-100)
  const setVolumeHandler = useCallback((newVolume: number) => {
    const boundedVolume = Math.max(0, Math.min(newVolume, 100));
    setVolume(boundedVolume);
    
    if (sound.current) {
      sound.current.volume(boundedVolume / 100);
    }
    
    if (boundedVolume === 0) {
      setIsMuted(true);
    } else if (isMuted) {
      setIsMuted(false);
    }
  }, [isMuted]);

  // Toggle mute
  const toggleMute = useCallback(() => {
    if (sound.current) {
      if (isMuted) {
        sound.current.volume(volume / 100);
        setIsMuted(false);
      } else {
        sound.current.volume(0);
        setIsMuted(true);
      }
    }
  }, [isMuted, volume]);

  // Toggle repeat mode
  const toggleRepeat = useCallback(() => {
    setRepeatMode((prev) => (prev + 1) % 3);
  }, []);

  // Play next track
  const nextTrack = useCallback(() => {
    if (playlist.length === 0 || !currentTrack) return;
    
    const currentIndex = playlist.findIndex(track => track.id === currentTrack.id);
    if (currentIndex === -1 || currentIndex === playlist.length - 1) {
      // If current track not in playlist or is last track, play first track
      playTrack(playlist[0]);
    } else {
      // Play next track
      playTrack(playlist[currentIndex + 1]);
    }
  }, [playlist, currentTrack, playTrack]);

  // Play previous track
  const previousTrack = useCallback(() => {
    if (playlist.length === 0 || !currentTrack) return;
    
    const currentIndex = playlist.findIndex(track => track.id === currentTrack.id);
    if (currentIndex === -1 || currentIndex === 0) {
      // If current track not in playlist or is first track, play last track
      playTrack(playlist[playlist.length - 1]);
    } else {
      // Play previous track
      playTrack(playlist[currentIndex - 1]);
    }
  }, [playlist, currentTrack, playTrack]);

  // Add track to playlist
  const addToPlaylist = useCallback((track: SoundCloudTrack) => {
    setPlaylist(prev => {
      // Check if track already exists in playlist
      if (prev.some(t => t.id === track.id)) {
        toast({
          title: "Already in Playlist",
          description: `"${track.title}" is already in your playlist.`,
        });
        return prev;
      }
      
      toast({
        title: "Added to Playlist",
        description: `"${track.title}" has been added to your playlist.`,
      });
      
      return [...prev, track];
    });
  }, [toast]);

  // Remove track from playlist
  const removeFromPlaylist = useCallback((trackId: number) => {
    setPlaylist(prev => prev.filter(track => track.id !== trackId));
  }, []);

  // Clear playlist
  const clearPlaylist = useCallback(() => {
    setPlaylist([]);
  }, []);

  // Update volume when sound instance changes
  useEffect(() => {
    if (sound.current) {
      sound.current.volume(isMuted ? 0 : volume / 100);
    }
  }, [sound, volume, isMuted]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      stopCurrentSound();
    };
  }, [stopCurrentSound]);

  const contextValue: PlayerContextType = {
    currentTrack,
    playlist,
    isPlaying,
    volume,
    isMuted,
    progress,
    duration,
    repeatMode,
    playTrack,
    playTrackById,
    pauseTrack,
    resumeTrack,
    togglePlay,
    nextTrack,
    previousTrack,
    seekPosition,
    setVolume: setVolumeHandler,
    toggleMute,
    toggleRepeat,
    addToPlaylist,
    removeFromPlaylist,
    clearPlaylist,
  };

  return (
    <PlayerContext.Provider value={contextValue}>
      {children}
    </PlayerContext.Provider>
  );
};
