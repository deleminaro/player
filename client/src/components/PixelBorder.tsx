import React from 'react';
import { cn } from '@/lib/utils';

interface PixelBorderProps extends React.HTMLAttributes<HTMLDivElement> {
  className?: string;
  children?: React.ReactNode;
}

const PixelBorder: React.FC<PixelBorderProps> = ({ 
  className,
  children,
  ...props
}) => {
  return (
    <div 
      className={cn("pixel-border", className)}
      {...props}
    >
      {children}
    </div>
  );
};

export default PixelBorder;
