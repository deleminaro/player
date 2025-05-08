import axios from "axios";

// Use RapidAPI for SoundCloud access
const RAPIDAPI_KEY = process.env.RAPIDAPI_KEY;

// Using a different RapidAPI endpoint for SoundCloud
const RAPIDAPI_HOST = "soundcloud-downloader3.p.rapidapi.com";
const RAPIDAPI_BASE_URL = "https://soundcloud-downloader3.p.rapidapi.com";

// Configure axios with RapidAPI headers
const rapidApiClient = axios.create({
  headers: {
    'X-RapidAPI-Key': RAPIDAPI_KEY,
    'X-RapidAPI-Host': RAPIDAPI_HOST
  }
});

// Transform RapidAPI response to match our SoundCloud schema
function transformSearchResults(results: any) {
  if (!results || !Array.isArray(results)) {
    return [];
  }
  
  return results.map(track => ({
    id: track.id || Date.now(),
    title: track.title || "Unknown Title",
    permalink_url: track.url || "#",
    artwork_url: track.artwork_url || track.thumbnail || null,
    duration: track.duration || track.length || 0,
    playback_count: track.playback_count || track.plays || 0,
    user: {
      username: track.username || track.artist || "Unknown Artist"
    },
    stream_url: track.stream_url || track.audio || null
  }));
}

function transformTrackData(track: any) {
  return {
    id: track.id || Date.now(),
    title: track.title || "Unknown Title",
    permalink_url: track.permalink_url || track.url || "#",
    artwork_url: track.artwork_url || track.thumbnail || null,
    duration: track.duration || track.length || 0,
    playback_count: track.playback_count || track.plays || 0,
    user: {
      username: track.username || track.artist || "Unknown Artist"
    },
    stream_url: track.audio_url || track.stream_url || track.audio || null
  };
}

// Mock data for development use when the API isn't available
const MOCK_TRACKS = [
  {
    id: 1001,
    title: "Demo Track 1",
    permalink_url: "https://example.com/track1",
    artwork_url: "https://i1.sndcdn.com/artworks-000108468163-dp0j6y-t500x500.jpg",
    duration: 180000,
    playback_count: 12500,
    user: { username: "Demo Artist 1" },
    stream_url: "https://cdn-web.tunezjam.com/audio/5d7f482116f9c1d3c3c84ab4f6a40ea1"
  },
  {
    id: 1002,
    title: "Demo Track 2",
    permalink_url: "https://example.com/track2",
    artwork_url: "https://i1.sndcdn.com/artworks-000108468163-dp0j6y-t500x500.jpg",
    duration: 210000,
    playback_count: 8700,
    user: { username: "Demo Artist 2" },
    stream_url: "https://cdn-web.tunezjam.com/audio/5d7f482116f9c1d3c3c84ab4f6a40ea1"
  }
];

export async function searchTracks(query: string, limit: number = 20) {
  try {
    console.log("Searching tracks with RapidAPI, query:", query);
    
    // First try using the search endpoint
    try {
      const response = await rapidApiClient.get(`${RAPIDAPI_BASE_URL}/soundcloud/search`, {
        params: {
          query: query
        },
      });
      
      if (response.data && response.data.length > 0) {
        const transformed = transformSearchResults(response.data);
        return transformed.slice(0, limit);
      }
    } catch (searchError) {
      console.log("Primary search endpoint failed, trying alternative");
    }
    
    // If that fails, try a second endpoint
    try {
      const response = await rapidApiClient.get(`${RAPIDAPI_BASE_URL}/search`, {
        params: {
          q: query
        },
      });
      
      if (response.data && Array.isArray(response.data.tracks)) {
        const transformed = transformSearchResults(response.data.tracks);
        return transformed.slice(0, limit);
      }
    } catch (altSearchError) {
      console.log("Alternative search endpoint failed");
    }
    
    // If all API attempts fail, return mock data for development
    console.log("All search endpoints failed, using mock data");
    return MOCK_TRACKS;
    
  } catch (error) {
    console.error("SoundCloud search error:", error);
    // Return mock data as a fallback
    return MOCK_TRACKS;
  }
}

export async function getTrack(id: number) {
  try {
    console.log("Getting track with RapidAPI, id:", id);
    
    // Try the first endpoint
    try {
      const response = await rapidApiClient.get(`${RAPIDAPI_BASE_URL}/track/metadata`, {
        params: { url: `https://soundcloud.com/tracks/${id}` }
      });
      
      if (response.data) {
        return transformTrackData(response.data);
      }
    } catch (trackError) {
      console.log("Primary track endpoint failed, trying alternative");
    }
    
    // Try alternative endpoint
    try {
      const response = await rapidApiClient.get(`${RAPIDAPI_BASE_URL}/track/${id}`);
      
      if (response.data) {
        return transformTrackData(response.data);
      }
    } catch (altTrackError) {
      console.log("Alternative track endpoint failed");
    }
    
    // Find in mock data as last resort
    const mockTrack = MOCK_TRACKS.find(track => track.id === id);
    if (mockTrack) return mockTrack;
    
    return MOCK_TRACKS[0]; // Return the first mock track if ID not found
  } catch (error) {
    console.error("Get track error:", error);
    return MOCK_TRACKS[0]; // Default to first mock track
  }
}

export async function getStreamUrl(trackId: number) {
  try {
    console.log("Getting stream URL with RapidAPI, trackId:", trackId);
    
    // Try to get the track info first
    const trackInfo = await getTrack(trackId);
    
    // If track info has a stream URL, return it
    if (trackInfo && trackInfo.stream_url) {
      return trackInfo.stream_url;
    }
    
    // If no stream URL in track info, try the download endpoint
    try {
      const response = await rapidApiClient.get(`${RAPIDAPI_BASE_URL}/track/download-url`, {
        params: { url: `https://soundcloud.com/tracks/${trackId}` }
      });
      
      if (response.data && response.data.url) {
        return response.data.url;
      }
    } catch (streamError) {
      console.log("Stream URL endpoint failed");
    }
    
    // Return mock stream URL as fallback
    return "https://cdn-web.tunezjam.com/audio/5d7f482116f9c1d3c3c84ab4f6a40ea1";
  } catch (error) {
    console.error("Stream URL error:", error);
    // Return mock stream URL
    return "https://cdn-web.tunezjam.com/audio/5d7f482116f9c1d3c3c84ab4f6a40ea1";
  }
}
