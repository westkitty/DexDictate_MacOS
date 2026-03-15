import React from 'react';
import {Img, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {drift, pulseScale} from '../lib/motion';

type BrandBadgeProps = {
  size: number;
  shadowColor?: string;
};

export const BrandBadge: React.FC<BrandBadgeProps> = ({size, shadowColor = 'rgba(0, 0, 0, 0.38)'}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const bob = drift(frame, 10, 0.6);
  const scale = pulseScale(frame, fps, 2);

  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        overflow: 'hidden',
        transform: `translateY(${bob}px) scale(${scale})`,
        boxShadow: `0 40px 120px ${shadowColor}`,
        border: '10px solid rgba(255,255,255,0.18)',
        backgroundColor: '#0d1016',
      }}
    >
      <Img
        src={staticFile('dexter-icon.png')}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'cover',
        }}
      />
    </div>
  );
};
