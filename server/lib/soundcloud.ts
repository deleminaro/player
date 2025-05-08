import axios from "axios";

// Use RapidAPI for SoundCloud access
const RAPIDAPI_KEY = process.env.RAPIDAPI_KEY;
const RAPIDAPI_HOST = "soundcloud-scraper2.p.rapidapi.com";
const RAPIDAPI_BASE_URL = "https://soundcloud-scraper2.p.rapidapi.com";

// Configure axios with RapidAPI headers
const rapidApiClient = axios.create({
  headers: {
    'X-RapidAPI-Key': RAPIDAPI_KEY,
    'X-RapidAPI-Host': RAPIDAPI_HOST
  }
});

// Transform RapidAPI response to match our SoundCloud schema
function transformTrackData(track: any) {
  return {
    id: track.id || track.trackId,
    title: track.title,
    permalink_url: track.url || track.permalink_url,
    artwork_url: track.thumbnail || track.artwork_url,
    duration: track.duration || 0,
    playback_count: track.playCount || track.playback_count || 0,
    user: {
      username: track.artist || track.user?.username || "Unknown Artist"
    },
    stream_url: track.streamUrl || track.stream_url
  };
}

export async function searchTracks(query: string, limit: number = 20) {
  try {
    console.log("Searching tracks with RapidAPI, query:", query);
    const response = await rapidApiClient.get(`${RAPIDAPI_BASE_URL}/v1/search/tracks`, {
      params: {
        query: query,
        limit: limit.toString()
      },
    });
    
    if (response.data && response.data.tracks) {
      return response.data.tracks.map(transformTrackData);
    }
    
    return [];
  } catch (error) {
    console.error("SoundCloud search error:", error);
    throw new Error("Failed to search tracks");
  }
}

export async function getTrack(id: number) {
  try {
    console.log("Getting track with RapidAPI, id:", id);
    const response = await rapidApiClient.get(`${RAPIDAPI_BASE_URL}/v1/track/info`, {
      params: {
        track: id.toString()
      }
    });
    
    if (response.data) {
      return transformTrackData(response.data);
    }
    
    throw new Error("Track not found");
  } catch (error) {
    console.error("Get track error:", error);
    throw new Error("Failed to get track");
  }
}

export async function getStreamUrl(trackId: number) {
  try {
    console.log("Getting stream URL with RapidAPI, trackId:", trackId);
    // Get track info first, which includes the stream URL
    const trackInfo = await getTrack(trackId);
    
    if (trackInfo && trackInfo.stream_url) {
      return trackInfo.stream_url;
    }
    
    throw new Error("Stream URL not found");
  } catch (error) {
    console.error("Stream URL error:", error);
    throw new Error("Failed to get stream URL");
  }
}
