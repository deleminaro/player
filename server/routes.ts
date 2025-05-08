import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import axios from "axios";
import { insertTrackSchema } from "@shared/schema";

const SOUNDCLOUD_CLIENT_ID = "f6k2kBKdKxsBaJCEeHQHScqQLINy5UUN";
const SOUNDCLOUD_API_URL = "https://api.soundcloud.com";

export async function registerRoutes(app: Express): Promise<Server> {
  // SoundCloud search endpoint
  app.get("/api/soundcloud/search", async (req, res) => {
    try {
      const { q, limit = 20 } = req.query;
      
      if (!q) {
        return res.status(400).json({ message: "Search query is required" });
      }
      
      const response = await axios.get(`${SOUNDCLOUD_API_URL}/tracks`, {
        params: {
          q,
          limit,
          client_id: SOUNDCLOUD_CLIENT_ID,
          linked_partitioning: 1,
        },
      });
      
      res.json(response.data.collection || []);
    } catch (error) {
      console.error("SoundCloud search error:", error);
      res.status(500).json({ message: "Failed to search tracks" });
    }
  });
  
  // Get track by ID endpoint
  app.get("/api/soundcloud/tracks/:id", async (req, res) => {
    try {
      const { id } = req.params;
      
      const response = await axios.get(`${SOUNDCLOUD_API_URL}/tracks/${id}`, {
        params: {
          client_id: SOUNDCLOUD_CLIENT_ID,
        },
      });
      
      res.json(response.data);
    } catch (error) {
      console.error("Get track error:", error);
      res.status(500).json({ message: "Failed to get track" });
    }
  });
  
  // Get stream URL endpoint
  app.get("/api/soundcloud/stream/:id", async (req, res) => {
    try {
      const { id } = req.params;
      
      // First get the track info
      const trackResponse = await axios.get(`${SOUNDCLOUD_API_URL}/tracks/${id}`, {
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
      
      const streamUrl = streamResponse.headers.location;
      
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
