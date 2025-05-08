import React from "react";
import { Track } from "@shared/schema";
import { usePlayer } from "../hooks/usePlayer";
import { formatTime, formatRelativeTime } from "../lib/utils";

interface RecentlyPlayedProps {
  tracks: Track[];
}

const RecentlyPlayed: React.FC<RecentlyPlayedProps> = ({ tracks }) => {
  const { playTrackById, addToPlaylist } = usePlayer();

  if (tracks.length === 0) {
    return null;
  }

  return (
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
              <th className="px-4 py-3 text-left text-xs font-pixel">PLAYED</th>
              <th className="px-4 py-3 text-right text-xs font-pixel"></th>
            </tr>
          </thead>
          <tbody>
            {tracks.map((track, index) => (
              <tr 
                key={`${track.id}-${track.played_at}`}
                className="border-b border-pixelgray hover:bg-pixelgray/50 cursor-pointer"
                onClick={() => playTrackById(track.soundcloud_id)}
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
                <td className="px-4 py-3 text-sm text-light/70">
                  {formatRelativeTime(new Date(track.played_at))}
                </td>
                <td className="px-4 py-3 text-right">
                  <button 
                    className="text-light/70 hover:text-primary"
                    onClick={(e) => {
                      e.stopPropagation();
                      addToPlaylist({
                        id: track.soundcloud_id,
                        title: track.title,
                        artwork_url: track.artwork_url || null,
                        duration: track.duration || 0,
                        permalink_url: track.permalink_url || '',
                        user: {
                          id: 0,
                          username: track.artist,
                          avatar_url: null
                        }
                      });
                    }}
                  >
                    <i className="ri-add-line"></i>
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default RecentlyPlayed;
