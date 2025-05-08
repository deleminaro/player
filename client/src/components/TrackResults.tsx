import React from "react";
import { SoundCloudTrack } from "@shared/schema";
import { usePlayer } from "../hooks/usePlayer";
import { formatTime } from "../lib/utils";

interface TrackResultsProps {
  tracks: SoundCloudTrack[];
  title?: string;
}

const TrackResults: React.FC<TrackResultsProps> = ({ 
  tracks, 
  title = "Search Results" 
}) => {
  const { playTrack, currentTrack } = usePlayer();

  if (tracks.length === 0) {
    return null;
  }

  return (
    <div>
      <h2 className="font-pixel text-xl mb-6">{title}</h2>
      
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {tracks.map(track => (
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

export default TrackResults;
