import { createRoot } from "react-dom/client";
import App from "./App";
import "./index.css";
import { PlayerProvider } from "./context/PlayerContext";
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "./lib/queryClient";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";

createRoot(document.getElementById("root")!).render(
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <PlayerProvider>
        <App />
        <Toaster />
      </PlayerProvider>
    </TooltipProvider>
  </QueryClientProvider>
);
