import React, { useState, useEffect } from "react";
import { useSoundCloud } from "../hooks/useSoundCloud";
import SearchBar from "../components/SearchBar";
import { SoundCloudTrack, Track } from "@shared/schema";
import { formatTime } from "../lib/utils";
import { Howl } from "howler";
import { useToast } from "@/hooks/use-toast";

// Add custom interface for our Howl instance with _progressInterval
interface ExtendedHowl extends Howl {
  _progressInterval?: number;
}

// Simple player implementation directly in the Home component
const Home: React.FC = () => {
  const { 
    searchTracks, 
    searchResults,
    recentlyPlayed,
    refetchHistory
  } = useSoundCloud();
  
  // Player state
  const [currentTrack, setCurrentTrack] = useState<SoundCloudTrack | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [sound, setSound] = useState<ExtendedHowl | null>(null);
  const [progress, setProgress] = useState(0);
  const [duration, setDuration] = useState(0);
  const { toast } = useToast();

  // Handle cleanup on unmount
  useEffect(() => {
    return () => {
      if (sound) {
        sound.stop();
        sound.unload();
      }
    };
  }, [sound]);

  // Play track function
  const playTrack = async (track: SoundCloudTrack) => {
    try {
      // Stop current sound if playing
      if (sound) {
        sound.stop();
        sound.unload();
      }

      // Record this track in history
      try {
        await fetch('/api/history', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            soundcloud_id: String(track.id), // Convert ID to string to handle large Deezer IDs
            title: track.title,
            artist: track.user.username,
            artwork_url: track.artwork_url,
            duration: track.duration,
            permalink_url: track.permalink_url,
            playback_count: track.playback_count || 0,
          }),
        });
        refetchHistory();
      } catch (error) {
        console.error('Failed to record history:', error);
      }

      // Get stream URL
      let streamUrl = '';
      try {
        const response = await fetch(`/api/soundcloud/stream/${track.id}`);
        if (!response.ok) {
          throw new Error("Failed to get stream URL");
        }
        const data = await response.json();
        
        // Handle various response formats
        if (typeof data.url === 'string') {
          streamUrl = data.url;
        } else if (data.url && typeof data.url.url === 'string') {
          streamUrl = data.url.url;
        } else if (track.stream_url) {
          streamUrl = track.stream_url;
        } else {
          throw new Error("Invalid stream URL format");
        }
        
        console.log("Using stream URL:", streamUrl);
      } catch (error) {
        console.error("Error getting stream URL:", error);
        toast({
          title: "Playback Error",
          description: "Couldn't load stream URL for this track.",
          variant: "destructive"
        });
        return;
      }

      // Create new Howl instance
      const newSound = new Howl({
        src: [streamUrl],
        html5: true,
        onplay: () => {
          setIsPlaying(true);
          // Update progress on interval
          const progressInterval = window.setInterval(() => {
            if (newSound.playing()) {
              setProgress(newSound.seek() as number);
            } else {
              window.clearInterval(progressInterval);
            }
          }, 500);
          // Cast to our extended type to allow the property assignment
          (newSound as ExtendedHowl)._progressInterval = progressInterval;
        },
        onload: () => {
          setDuration(newSound.duration());
        },
        onend: () => {
          setIsPlaying(false);
        },
        onpause: () => {
          setIsPlaying(false);
        },
        onstop: () => {
          setIsPlaying(false);
          // Cast to our extended type to access the property
          const extendedSound = newSound as ExtendedHowl;
          if (extendedSound._progressInterval) {
            window.clearInterval(extendedSound._progressInterval);
          }
        }
      }) as ExtendedHowl;

      setSound(newSound);
      setCurrentTrack(track);
      newSound.play();
    } catch (error) {
      console.error('Failed to play track:', error);
      toast({
        title: "Playback Error",
        description: "Failed to play track. Please try another one.",
        variant: "destructive",
      });
    }
  };

  // Toggle play/pause
  const togglePlay = () => {
    if (!sound) return;
    
    if (isPlaying) {
      sound.pause();
    } else {
      sound.play();
    }
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-pixel mb-8 text-primary">PixelBeats</h1>
      <SearchBar onSearch={searchTracks} />
      
      {/* Current Track Player */}
      {currentTrack && (
        <div className="mb-8 bg-pixelgray rounded-lg overflow-hidden pixel-border">
          <div className="md:flex">
            {/* Album art */}
            <div className="md:w-1/3 relative">
              {currentTrack?.artwork_url ? (
                <img 
                  src={currentTrack.artwork_url.replace('-large', '-t500x500')} 
                  alt={`${currentTrack.title} artwork`}
                  className="w-full aspect-square object-cover"
                />
              ) : (
                <div className="w-full aspect-square bg-dark flex items-center justify-center">
                  <div className="text-4xl text-primary">
                    <i className="ri-music-fill"></i>
                  </div>
                </div>
              )}
            </div>
            
            {/* Track info and controls */}
            <div className="md:w-2/3 p-6 flex flex-col justify-between">
              <div className="mb-4">
                <h2 className="font-pixel text-xl mb-2 truncate">
                  {currentTrack?.title}
                </h2>
                <p className="text-light/80 truncate">
                  {currentTrack?.user?.username}
                </p>
              </div>
              
              {/* Progress bar */}
              <div className="mb-4">
                <div className="flex justify-between text-xs mb-1">
                  <span>{formatTime(progress)}</span>
                  <span>{formatTime(duration)}</span>
                </div>
                <div 
                  className="pixel-progress relative w-full cursor-pointer" 
                  onClick={(e) => {
                    if (!sound || !duration) return;
                    const progressBar = e.currentTarget;
                    const rect = progressBar.getBoundingClientRect();
                    const offsetX = e.clientX - rect.left;
                    const percentage = offsetX / rect.width;
                    const seekTime = Math.max(0, Math.min(percentage * duration, duration));
                    sound.seek(seekTime);
                    setProgress(seekTime);
                  }}
                >
                  <div 
                    className="absolute h-full bg-primary" 
                    style={{ width: `${(progress / Math.max(duration, 1)) * 100}%` }}
                  ></div>
                </div>
              </div>
              
              {/* Controls */}
              <div className="flex justify-center items-center">
                <button 
                  className="pixel-button p-2 text-2xl hover:text-primary"
                  onClick={togglePlay}
                >
                  <i className={isPlaying ? "ri-pause-fill" : "ri-play-fill"}></i>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
      
      {/* Search Results */}
      {searchResults.length > 0 && (
        <div className="mt-8">
          <h2 className="font-pixel text-xl mb-6">Search Results</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {searchResults.map(track => (
              <div 
                key={track.id} 
                className={`bg-pixelgray rounded-lg overflow-hidden hover:pixel-border transition-shadow cursor-pointer ${currentTrack?.id === track.id ? 'pixel-border' : ''}`}
                onClick={() => playTrack(track)}
              >
                {track.artwork_url ? (
                  <img 
                    src={track.artwork_url.replace('-large', '-t500x500')} 
                    alt={`${track.title} artwork`}
                    className="w-full aspect-video object-cover"
                  />
                ) : (
                  <div className="w-full aspect-video bg-dark flex items-center justify-center">
                    <div className="text-4xl text-primary">
                      <i className="ri-music-fill"></i>
                    </div>
                  </div>
                )}
                <div className="p-4">
                  <h3 className="font-medium truncate">{track.title}</h3>
                  <p className="text-light/70 text-sm truncate">{track.user.username}</p>
                  <div className="flex justify-between items-center mt-2">
                    <span className="text-xs text-light/60">{formatTime(track.duration / 1000)}</span>
                    <div className="flex space-x-2">
                      <span className="text-xs flex items-center text-light/60">
                        <i className="ri-play-line mr-1"></i> 
                        {formatPlayCount(track.playback_count)}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
      
      {/* Recently Played */}
      {recentlyPlayed.length > 0 && (
        <div className="mt-12">
          <h2 className="font-pixel text-xl mb-6">Recently Played</h2>
          <div className="overflow-x-auto">
            <table className="w-full min-w-full">
              <thead className="bg-pixelgray">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-pixel">#</th>
                  <th className="px-4 py-3 text-left text-xs font-pixel">TRACK</th>
                  <th className="px-4 py-3 text-left text-xs font-pixel">ARTIST</th>
                  <th className="px-4 py-3 text-left text-xs font-pixel">DURATION</th>
                </tr>
              </thead>
              <tbody>
                {recentlyPlayed.map((track, index) => (
                  <tr 
                    key={`${track.id}-${track.played_at}`}
                    className="border-b border-pixelgray hover:bg-pixelgray/50 cursor-pointer"
                    onClick={async () => {
                      try {
                        // Fetch full track data from SoundCloud
                        const response = await fetch(`/api/soundcloud/tracks/${track.soundcloud_id}`);
                        if (!response.ok) {
                          throw new Error("Failed to get track data");
                        }
                        const trackData = await response.json();
                        playTrack(trackData);
                      } catch (error) {
                        console.error("Error loading track:", error);
                        toast({
                          title: "Error",
                          description: "Couldn't load track data.",
                          variant: "destructive"
                        });
                      }
                    }}
                  >
                    <td className="px-4 py-3 text-sm">{index + 1}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center">
                        {track.artwork_url ? (
                          <img 
                            src={track.artwork_url}
                            alt={track.title}
                            className="w-10 h-10 object-cover flex-shrink-0 mr-3"
                          />
                        ) : (
                          <div className="w-10 h-10 bg-tertiary flex-shrink-0 mr-3 flex items-center justify-center">
                            <i className="ri-music-fill text-light/80"></i>
                          </div>
                        )}
                        <span className="truncate">{track.title}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-light/70">{track.artist}</td>
                    <td className="px-4 py-3 text-sm text-light/70">
                      {track.duration ? formatTime(track.duration / 1000) : "--:--"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};

// Helper function to format play count
const formatPlayCount = (count?: number): string => {
  if (!count) return "0";
  
  if (count >= 1000000) {
    return `${(count / 1000000).toFixed(1)}M`;
  } else if (count >= 1000) {
    return `${(count / 1000).toFixed(1)}K`;
  }
  
  return count.toString();
};

export default Home;
