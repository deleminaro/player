import { useState, useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import { soundCloudClient } from "../lib/soundcloud";
import { SoundCloudTrack, Track } from "@shared/schema";
import { useToast } from "@/hooks/use-toast";

export function useSoundCloud() {
  const [searchResults, setSearchResults] = useState<SoundCloudTrack[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const { toast } = useToast();

  // Get recently played from server
  const { 
    data: recentlyPlayed = [] as Track[],
    isLoading: isLoadingHistory,
    error: historyError,
    refetch: refetchHistory
  } = useQuery<Track[]>({
    queryKey: ['/api/history'],
  });

  // Search tracks
  const searchTracks = useCallback(async (query: string) => {
    if (!query.trim()) return;
    
    setIsSearching(true);
    
    try {
      const results = await soundCloudClient.search(query);
      setSearchResults(results);
    } catch (error) {
      console.error('Search failed:', error);
      toast({
        title: "Search Failed",
        description: "Could not complete search. Please try again.",
        variant: "destructive",
      });
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  }, [toast]);

  return {
    searchTracks,
    searchResults,
    isSearching,
    recentlyPlayed,
    isLoadingHistory,
    historyError,
    refetchHistory
  };
}
