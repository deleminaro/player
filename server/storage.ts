import { tracks, users, type User, type InsertUser, type Track, type InsertTrack } from "@shared/schema";
import { db } from "./db";
import { eq, desc } from "drizzle-orm";

export interface IStorage {
  getUser(id: number): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
  addTrackToHistory(track: InsertTrack): Promise<Track>;
  getRecentlyPlayed(limit?: number): Promise<Track[]>;
}

export class DatabaseStorage implements IStorage {
  async getUser(id: number): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.id, id));
    return user;
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.username, username));
    return user;
  }

  async createUser(insertUser: InsertUser): Promise<User> {
    const [user] = await db.insert(users).values(insertUser).returning();
    return user;
  }

  async addTrackToHistory(insertTrack: InsertTrack): Promise<Track> {
    // Check if track already exists in history
    const [existingTrack] = await db.select()
      .from(tracks)
      .where(eq(tracks.soundcloud_id, insertTrack.soundcloud_id));
    
    // If it exists, delete it (we'll re-add it with updated timestamp)
    if (existingTrack) {
      await db.delete(tracks).where(eq(tracks.id, existingTrack.id));
    }
    
    // Insert the track
    const [track] = await db.insert(tracks).values(insertTrack).returning();
    
    // Keep only the most recent 20 tracks
    const allTracks = await db.select()
      .from(tracks)
      .orderBy(desc(tracks.played_at));
    
    if (allTracks.length > 20) {
      // Delete older tracks beyond the 20 limit
      const tracksToRemove = allTracks.slice(20);
      for (const oldTrack of tracksToRemove) {
        await db.delete(tracks).where(eq(tracks.id, oldTrack.id));
      }
    }
    
    return track;
  }

  async getRecentlyPlayed(limit: number = 20): Promise<Track[]> {
    return await db.select()
      .from(tracks)
      .orderBy(desc(tracks.played_at))
      .limit(limit);
  }
}

export const storage = new DatabaseStorage();
