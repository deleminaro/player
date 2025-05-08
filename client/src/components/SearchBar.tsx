import { useState } from "react";
import { useSoundCloud } from "../hooks/useSoundCloud";
import { useToast } from "@/hooks/use-toast";

interface SearchBarProps {
  onSearch: (query: string) => void;
}

const SearchBar = ({ onSearch }: SearchBarProps) => {
  const [searchQuery, setSearchQuery] = useState("");
  const { isSearching } = useSoundCloud();
  const { toast } = useToast();

  const handleSearch = () => {
    if (!searchQuery.trim()) {
      toast({
        title: "Search query is empty",
        description: "Please enter a search term to find tracks",
        variant: "destructive",
      });
      return;
    }
    
    onSearch(searchQuery);
  };

  const handleKeyUp = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") {
      handleSearch();
    }
  };

  return (
    <div className="mb-8">
      <div className="flex items-center rounded-lg overflow-hidden bg-pixelgray pixel-border">
        <input
          type="text"
          placeholder="Search tracks, artists, albums..."
          className="bg-pixelgray border-none w-full px-4 py-3 focus:outline-none"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          onKeyUp={handleKeyUp}
        />
        <button
          className="bg-pixelgray px-4 py-3 text-xl hover:text-primary transition-colors"
          onClick={handleSearch}
          disabled={isSearching}
        >
          <i className="ri-search-line"></i>
        </button>
      </div>

      {/* Search loading state */}
      {isSearching && (
        <div className="mt-4">
          <div className="flex justify-center py-4">
            <div className="loading-pixel bg-primary animate-pixel-pulse"></div>
            <div className="loading-pixel bg-secondary animate-pixel-pulse" style={{ animationDelay: "0.2s" }}></div>
            <div className="loading-pixel bg-tertiary animate-pixel-pulse" style={{ animationDelay: "0.4s" }}></div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SearchBar;
