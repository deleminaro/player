import React from "react";
import { Link } from "wouter";
import PixelBorder from "./PixelBorder";

const Footer: React.FC = () => {
  return (
    <footer className="bg-pixelgray py-8 mt-12">
      <div className="container mx-auto px-4">
        <div className="flex flex-col md:flex-row justify-between items-center">
          <div className="mb-6 md:mb-0">
            <div className="flex items-center space-x-2 mb-4">
              <PixelBorder className="w-8 h-8 bg-primary" />
              <h3 className="font-pixel text-sm text-primary">PixelBeats</h3>
            </div>
            <p className="text-sm text-light/70">Powered by SoundCloud API</p>
          </div>
          
          <div className="grid grid-cols-2 md:grid-cols-3 gap-8">
            <div>
              <h4 className="font-pixel text-xs mb-4">Navigation</h4>
              <ul className="space-y-2 text-sm">
                <li><Link href="/" className="text-light/70 hover:text-primary">Discover</Link></li>
                <li><Link href="/library" className="text-light/70 hover:text-primary">Library</Link></li>
                <li><Link href="/history" className="text-light/70 hover:text-primary">History</Link></li>
              </ul>
            </div>
            
            <div>
              <h4 className="font-pixel text-xs mb-4">Legal</h4>
              <ul className="space-y-2 text-sm">
                <li><Link href="/terms" className="text-light/70 hover:text-primary">Terms of Use</Link></li>
                <li><Link href="/privacy" className="text-light/70 hover:text-primary">Privacy Policy</Link></li>
                <li><Link href="/cookies" className="text-light/70 hover:text-primary">Cookie Policy</Link></li>
              </ul>
            </div>
            
            <div>
              <h4 className="font-pixel text-xs mb-4">Connect</h4>
              <div className="flex space-x-4">
                <a href="#" className="text-light/70 hover:text-primary text-xl">
                  <i className="ri-twitter-line"></i>
                </a>
                <a href="#" className="text-light/70 hover:text-primary text-xl">
                  <i className="ri-instagram-line"></i>
                </a>
                <a href="#" className="text-light/70 hover:text-primary text-xl">
                  <i className="ri-github-line"></i>
                </a>
              </div>
            </div>
          </div>
        </div>
        
        <div className="mt-8 pt-6 border-t border-pixelgray/50 text-center">
          <p className="text-xs text-light/50">
            © {new Date().getFullYear()} PixelBeats. Not affiliated with SoundCloud.
          </p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
