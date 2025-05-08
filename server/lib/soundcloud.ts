import axios from "axios";

const SOUNDCLOUD_CLIENT_ID = "f6k2kBKdKxsBaJCEeHQHScqQLINy5UUN";
const SOUNDCLOUD_API_URL = "https://api.soundcloud.com";

export async function searchTracks(query: string, limit: number = 20) {
  try {
    const response = await axios.get(`${SOUNDCLOUD_API_URL}/tracks`, {
      params: {
        q: query,
        limit,
        client_id: SOUNDCLOUD_CLIENT_ID,
        linked_partitioning: 1,
      },
    });
    
    return response.data.collection || [];
  } catch (error) {
    console.error("SoundCloud search error:", error);
    throw new Error("Failed to search tracks");
  }
}

export async function getTrack(id: number) {
  try {
    const response = await axios.get(`${SOUNDCLOUD_API_URL}/tracks/${id}`, {
      params: {
        client_id: SOUNDCLOUD_CLIENT_ID,
      },
    });
    
    return response.data;
  } catch (error) {
    console.error("Get track error:", error);
    throw new Error("Failed to get track");
  }
}

export async function getStreamUrl(trackId: number) {
  try {
    // First get the track info
    const trackResponse = await axios.get(`${SOUNDCLOUD_API_URL}/tracks/${trackId}`, {
      params: {
        client_id: SOUNDCLOUD_CLIENT_ID,
      },
    });
    
    // Then get the stream URL
    const streamResponse = await axios.get(`${trackResponse.data.stream_url}`, {
      params: {
        client_id: SOUNDCLOUD_CLIENT_ID,
      },
      maxRedirects: 0,
      validateStatus: (status) => status === 302,
    });
    
    return streamResponse.headers.location;
  } catch (error) {
    console.error("Stream URL error:", error);
    throw new Error("Failed to get stream URL");
  }
}
