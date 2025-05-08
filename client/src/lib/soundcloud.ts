import { SoundCloudTrack } from "@shared/schema";

// Create a type for the SoundCloud SDK loaded from the CDN
interface SoundCloudSDK {
  initialize: (options: { client_id: string }) => void;
  get: (path: string, params?: Record<string, any>) => Promise<any>;
  stream: (url: string, options?: Record<string, any>) => any;
}

declare global {
  interface Window {
    SC: SoundCloudSDK;
  }
}

// Client-side helper for SoundCloud API
export class SoundCloudClient {
  private static instance: SoundCloudClient;
  private clientId: string;
  private initialized: boolean = false;
  private initPromise: Promise<void> | null = null;

  private constructor(clientId: string) {
    this.clientId = clientId;
  }

  public static getInstance(clientId: string): SoundCloudClient {
    if (!SoundCloudClient.instance) {
      SoundCloudClient.instance = new SoundCloudClient(clientId);
    }
    return SoundCloudClient.instance;
  }

  async initialize(): Promise<void> {
    if (this.initialized) return Promise.resolve();
    
    if (this.initPromise) return this.initPromise;
    
    this.initPromise = new Promise<void>((resolve, reject) => {
      if (window.SC) {
        window.SC.initialize({ client_id: this.clientId });
        this.initialized = true;
        resolve();
        return;
      }
      
      const script = document.createElement('script');
      script.src = 'https://connect.soundcloud.com/sdk/sdk-3.3.2.js';
      script.async = true;
      
      script.onload = () => {
        window.SC.initialize({ client_id: this.clientId });
        this.initialized = true;
        resolve();
      };
      
      script.onerror = () => {
        reject(new Error('Failed to load SoundCloud SDK'));
      };
      
      document.body.appendChild(script);
    });
    
    return this.initPromise;
  }

  async search(query: string, limit: number = 20): Promise<SoundCloudTrack[]> {
    await this.initialize();
    
    try {
      // First try with the client-side SDK
      const response = await window.SC.get('/tracks', {
        q: query,
        limit,
      });
      
      return response;
    } catch (error) {
      // Fallback to server proxy if client-side API fails
      const response = await fetch(`/api/soundcloud/search?q=${encodeURIComponent(query)}&limit=${limit}`);
      
      if (!response.ok) {
        throw new Error(`SoundCloud search failed: ${response.statusText}`);
      }
      
      return await response.json();
    }
  }

  async getTrack(trackId: number): Promise<SoundCloudTrack> {
    await this.initialize();
    
    try {
      const response = await window.SC.get(`/tracks/${trackId}`);
      return response;
    } catch (error) {
      const response = await fetch(`/api/soundcloud/tracks/${trackId}`);
      
      if (!response.ok) {
        throw new Error(`Failed to get track: ${response.statusText}`);
      }
      
      return await response.json();
    }
  }

  async getStreamUrl(track: SoundCloudTrack): Promise<string> {
    await this.initialize();
    
    try {
      if (track.stream_url) {
        return `${track.stream_url}?client_id=${this.clientId}`;
      }
      
      // Try to get the stream URL through the SDK
      const streamUrl = await window.SC.get(`/tracks/${track.id}/stream`);
      return streamUrl;
    } catch (error) {
      // Fallback to server proxy
      const response = await fetch(`/api/soundcloud/stream/${track.id}`);
      
      if (!response.ok) {
        throw new Error(`Failed to get stream URL: ${response.statusText}`);
      }
      
      const { url } = await response.json();
      return url;
    }
  }
}

// Export an instance with the provided client ID
export const soundCloudClient = SoundCloudClient.getInstance("f6k2kBKdKxsBaJCEeHQHScqQLINy5UUN");
