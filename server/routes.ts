import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import { insertTrackSchema } from "@shared/schema";
import * as soundcloudApi from "./lib/soundcloud";

export async function registerRoutes(app: Express): Promise<Server> {
  // SoundCloud search endpoint
  app.get("/api/soundcloud/search", async (req, res) => {
    try {
      const { q, limit = 20 } = req.query;
      
      if (!q) {
        return res.status(400).json({ message: "Search query is required" });
      }
      
      const tracks = await soundcloudApi.searchTracks(q.toString(), Number(limit));
      res.json(tracks);
    } catch (error) {
      console.error("SoundCloud search error:", error);
      res.status(500).json({ message: "Failed to search tracks" });
    }
  });
  
  // Get track by ID endpoint
  app.get("/api/soundcloud/tracks/:id", async (req, res) => {
    try {
      const { id } = req.params;
      
      const track = await soundcloudApi.getTrack(Number(id));
      res.json(track);
    } catch (error) {
      console.error("Get track error:", error);
      res.status(500).json({ message: "Failed to get track" });
    }
  });
  
  // Get stream URL endpoint
  app.get("/api/soundcloud/stream/:id", async (req, res) => {
    try {
      const { id } = req.params;
      
      const streamUrl = await soundcloudApi.getStreamUrl(Number(id));
      res.json({ url: streamUrl });
    } catch (error) {
      console.error("Stream URL error:", error);
      res.status(500).json({ message: "Failed to get stream URL" });
    }
  });
  
  // Add track to history
  app.post("/api/history", async (req, res) => {
    try {
      const trackData = insertTrackSchema.parse(req.body);
      
      await storage.addTrackToHistory(trackData);
      
      res.status(201).json({ message: "Track added to history" });
    } catch (error) {
      console.error("Add to history error:", error);
      res.status(400).json({ message: "Invalid track data" });
    }
  });
  
  // Get recently played tracks
  app.get("/api/history", async (req, res) => {
    try {
      const history = await storage.getRecentlyPlayed();
      res.json(history);
    } catch (error) {
      console.error("Get history error:", error);
      res.status(500).json({ message: "Failed to get history" });
    }
  });

  const httpServer = createServer(app);
  return httpServer;
}
