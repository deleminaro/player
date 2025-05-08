import { pgTable, text, serial, integer, boolean, timestamp } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

// User table for authentication (future expansion)
export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  username: text("username").notNull().unique(),
  password: text("password").notNull(),
});

export const insertUserSchema = createInsertSchema(users).pick({
  username: true,
  password: true,
});

export type InsertUser = z.infer<typeof insertUserSchema>;
export type User = typeof users.$inferSelect;

// Track table for recently played history
export const tracks = pgTable("tracks", {
  id: serial("id").primaryKey(),
  soundcloud_id: text("soundcloud_id").notNull(), // Changed to text to handle large IDs
  title: text("title").notNull(),
  artist: text("artist").notNull(),
  artwork_url: text("artwork_url"),
  duration: integer("duration"),
  permalink_url: text("permalink_url"),
  playback_count: integer("playback_count"),
  played_at: timestamp("played_at").defaultNow().notNull(),
});

export const insertTrackSchema = createInsertSchema(tracks).omit({
  id: true,
  played_at: true,
});

export type InsertTrack = z.infer<typeof insertTrackSchema>;
export type Track = typeof tracks.$inferSelect;

// SoundCloud/Deezer API types
export const soundCloudTrackSchema = z.object({
  id: z.union([z.number(), z.string()]), // Allow both number and string IDs
  title: z.string(),
  permalink_url: z.string(),
  artwork_url: z.string().nullable(),
  duration: z.number(),
  playback_count: z.number().optional(),
  user: z.object({
    id: z.number().optional(), // Make this optional for compatibility
    username: z.string(),
    avatar_url: z.string().nullable().optional(),
  }),
  stream_url: z.string().optional(),
});

export type SoundCloudTrack = z.infer<typeof soundCloudTrackSchema>;
