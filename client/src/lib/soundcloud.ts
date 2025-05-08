import { SoundCloudTrack } from "@shared/schema";

// Client-side helper for SoundCloud API using our server endpoints
export class SoundCloudClient {
  private static instance: SoundCloudClient;
  
  // We won't use the SDK anymore since we're going through our server API
  private constructor() {}

  public static getInstance(clientId?: string): SoundCloudClient {
    if (!SoundCloudClient.instance) {
      SoundCloudClient.instance = new SoundCloudClient();
    }
    return SoundCloudClient.instance;
  }

  async search(query: string, limit: number = 20): Promise<SoundCloudTrack[]> {
    try {
      // Use our server API endpoint
      const response = await fetch(`/api/soundcloud/search?q=${encodeURIComponent(query)}&limit=${limit}`);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        console.error("Search failed:", errorData);
        throw new Error(`SoundCloud search failed: ${response.statusText}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error("Search error:", error);
      throw error;
    }
  }

  async getTrack(trackId: number): Promise<SoundCloudTrack> {
    try {
      const response = await fetch(`/api/soundcloud/tracks/${trackId}`);
      
      if (!response.ok) {
        throw new Error(`Failed to get track: ${response.statusText}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error("Get track error:", error);
      throw error;
    }
  }

  async getStreamUrl(track: SoundCloudTrack): Promise<string> {
    try {
      // If the track already has a streamUrl, use it directly
      if (track.stream_url) {
        return track.stream_url;
      }
      
      // Otherwise get it from our server API
      const response = await fetch(`/api/soundcloud/stream/${track.id}`);
      
      if (!response.ok) {
        throw new Error(`Failed to get stream URL: ${response.statusText}`);
      }
      
      const { url } = await response.json();
      return url;
    } catch (error) {
      console.error("Get stream URL error:", error);
      throw error;
    }
  }
}

// Export an instance
export const soundCloudClient = SoundCloudClient.getInstance();
