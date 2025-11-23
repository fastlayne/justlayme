import React from 'react';
import './ShinyText.css';

const ShinyText = ({
  children,
  className = '',
  speed = 3,
  disabled = false,
  shimmerWidth = '200px'
}) => {
  return (
    <span
      className={`shiny-text ${disabled ? 'shiny-text-disabled' : ''} ${className}`}
      style={{
        '--shimmer-speed': `${speed}s`,
        '--shimmer-width': shimmerWidth
      }}
    >
      {children}
    </span>
  );
};

export default ShinyText;
