import { tracks, users, type User, type InsertUser, type Track, type InsertTrack } from "@shared/schema";

export interface IStorage {
  getUser(id: number): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
  addTrackToHistory(track: InsertTrack): Promise<Track>;
  getRecentlyPlayed(limit?: number): Promise<Track[]>;
}

export class MemStorage implements IStorage {
  private users: Map<number, User>;
  private trackHistory: Track[];
  currentUserId: number;
  currentTrackId: number;

  constructor() {
    this.users = new Map();
    this.trackHistory = [];
    this.currentUserId = 1;
    this.currentTrackId = 1;
  }

  async getUser(id: number): Promise<User | undefined> {
    return this.users.get(id);
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    return Array.from(this.users.values()).find(
      (user) => user.username === username,
    );
  }

  async createUser(insertUser: InsertUser): Promise<User> {
    const id = this.currentUserId++;
    const user: User = { ...insertUser, id };
    this.users.set(id, user);
    return user;
  }

  async addTrackToHistory(insertTrack: InsertTrack): Promise<Track> {
    const id = this.currentTrackId++;
    const now = new Date();
    
    const track: Track = { 
      ...insertTrack, 
      id, 
      played_at: now 
    };
    
    // Check if this track exists in history already (by soundcloud_id)
    const existingIndex = this.trackHistory.findIndex(
      (t) => t.soundcloud_id === track.soundcloud_id
    );
    
    if (existingIndex !== -1) {
      // Remove the existing entry
      this.trackHistory.splice(existingIndex, 1);
    }
    
    // Add to the beginning of the array
    this.trackHistory.unshift(track);
    
    // Limit history to 20 items
    if (this.trackHistory.length > 20) {
      this.trackHistory = this.trackHistory.slice(0, 20);
    }
    
    return track;
  }

  async getRecentlyPlayed(limit: number = 20): Promise<Track[]> {
    return this.trackHistory.slice(0, limit);
  }
}

export const storage = new MemStorage();
