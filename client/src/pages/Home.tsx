import React from "react";
import { useSoundCloud } from "../hooks/useSoundCloud";
import SearchBar from "../components/SearchBar";

// Temporarily simplified Home component to debug the PlayerProvider issue
const Home: React.FC = () => {
  const { 
    searchTracks, 
    searchResults
  } = useSoundCloud();

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-pixel mb-8 text-primary">PixelBeats</h1>
      <SearchBar onSearch={searchTracks} />
      
      {searchResults.length > 0 && (
        <div className="mt-8">
          <h2 className="font-pixel text-xl mb-6">Search Results</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {searchResults.map(track => (
              <div 
                key={track.id} 
                className="bg-pixelgray rounded-lg overflow-hidden hover:pixel-border transition-shadow cursor-pointer"
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
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default Home;
