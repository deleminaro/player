import { useState } from "react";
import { Link } from "wouter";
import PixelBorder from "./PixelBorder";

const Header = () => {
  const [mobileMenuVisible, setMobileMenuVisible] = useState(false);

  const toggleMenu = () => {
    setMobileMenuVisible(!mobileMenuVisible);
  };

  return (
    <header className="border-b border-pixelgray">
      <div className="container mx-auto px-4 py-4 flex justify-between items-center">
        <div className="flex items-center space-x-2">
          <PixelBorder className="w-10 h-10 bg-primary" />
          <Link href="/" className="font-pixel text-lg sm:text-xl text-primary">
            PixelBeats
          </Link>
        </div>
        <nav className="hidden md:block">
          <ul className="flex space-x-6">
            <li><Link href="/" className="hover:text-primary transition-colors">Discover</Link></li>
            <li><Link href="/library" className="hover:text-primary transition-colors">Library</Link></li>
            <li><Link href="/history" className="hover:text-primary transition-colors">History</Link></li>
          </ul>
        </nav>
        <button 
          className="md:hidden text-2xl" 
          onClick={toggleMenu}
          aria-label="Toggle mobile menu"
        >
          <i className="ri-menu-line"></i>
        </button>
      </div>
      
      {/* Mobile menu */}
      <div className={`md:hidden ${mobileMenuVisible ? 'block' : 'hidden'}`}>
        <nav className="container mx-auto px-4 py-4 border-t border-pixelgray">
          <ul className="space-y-4">
            <li><Link href="/" className="block hover:text-primary transition-colors">Discover</Link></li>
            <li><Link href="/library" className="block hover:text-primary transition-colors">Library</Link></li>
            <li><Link href="/history" className="block hover:text-primary transition-colors">History</Link></li>
          </ul>
        </nav>
      </div>
    </header>
  );
};

export default Header;
