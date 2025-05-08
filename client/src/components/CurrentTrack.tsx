import React from "react";
import { usePlayer } from "../hooks/usePlayer";
import { formatTime } from "../lib/utils";

const CurrentTrack = () => {
  const { 
    currentTrack, 
    isPlaying, 
    togglePlay,
    nextTrack,
    previousTrack,
    volume,
    setVolume,
    isMuted,
    toggleMute,
    repeatMode,
    toggleRepeat,
    seekPosition,
    progress,
    duration,
    addToPlaylist
  } = usePlayer();

  const handleSeek = (e: React.MouseEvent<HTMLDivElement, MouseEvent>) => {
    const progressBar = e.currentTarget;
    const rect = progressBar.getBoundingClientRect();
    const offsetX = e.clientX - rect.left;
    const percentage = offsetX / rect.width;
    seekPosition(percentage);
  };

  return (
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
          <div className="absolute inset-0 bg-gradient-to-t from-dark/80 to-transparent flex items-end p-4 md:hidden">
            <div>
              <h2 className="font-pixel text-sm sm:text-base truncate">
                {currentTrack?.title || "No track selected"}
              </h2>
              <p className="text-light/80 truncate">
                {currentTrack?.user?.username || "Select a track to play"}
              </p>
            </div>
          </div>
        </div>
        
        {/* Track info and controls */}
        <div className="md:w-2/3 p-6 flex flex-col justify-between">
          <div className="hidden md:block mb-4">
            <h2 className="font-pixel text-xl mb-2 truncate">
              {currentTrack?.title || "No track selected"}
            </h2>
            <p className="text-light/80 truncate">
              {currentTrack?.user?.username || "Select a track to play"}
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
              onClick={handleSeek}
            >
              <div 
                className="absolute h-full bg-primary" 
                style={{ width: `${(progress / Math.max(duration, 1)) * 100}%` }}
              ></div>
            </div>
          </div>
          
          {/* Controls */}
          <div className="flex justify-between items-center controls-container">
            <div className="flex items-center space-x-4">
              <button 
                className="pixel-button p-2 text-lg hover:text-primary"
                onClick={previousTrack}
                disabled={!currentTrack}
              >
                <i className="ri-skip-back-fill"></i>
              </button>
              <button 
                className="pixel-button p-2 text-2xl hover:text-primary"
                onClick={togglePlay}
                disabled={!currentTrack}
              >
                <i className={isPlaying ? "ri-pause-fill" : "ri-play-fill"}></i>
              </button>
              <button 
                className="pixel-button p-2 text-lg hover:text-primary"
                onClick={nextTrack}
                disabled={!currentTrack}
              >
                <i className="ri-skip-forward-fill"></i>
              </button>
            </div>
            
            <div className="flex items-center space-x-6">
              <div className="flex items-center">
                <button 
                  className="text-lg hover:text-primary"
                  onClick={toggleMute}
                >
                  <i className={isMuted ? "ri-volume-mute-line" : "ri-volume-up-line"}></i>
                </button>
                <input 
                  type="range" 
                  min="0" 
                  max="100" 
                  value={volume} 
                  className="w-20 ml-2 accent-primary"
                  onChange={(e) => setVolume(parseInt(e.target.value))}
                />
              </div>
              <button 
                className="pixel-button p-2 hover:text-primary"
                onClick={toggleRepeat}
              >
                <i className={
                  repeatMode === 0 ? "ri-repeat-line" : 
                  repeatMode === 1 ? "ri-repeat-fill" : 
                  "ri-repeat-one-fill"
                }></i>
              </button>
              <button 
                className="pixel-button p-2 hover:text-primary"
                onClick={() => currentTrack && addToPlaylist(currentTrack)}
                disabled={!currentTrack}
              >
                <i className="ri-add-line"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CurrentTrack;
