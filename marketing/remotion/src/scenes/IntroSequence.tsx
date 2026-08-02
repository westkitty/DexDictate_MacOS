import React from 'react';
import {useCurrentFrame} from 'remotion';
import {BrandBadge} from '../components/BrandBadge';
import {SceneFrame} from '../components/SceneFrame';
import type {StorySection} from '../data/video-data';
import {clampOpacity, slideRight, slideUp} from '../lib/motion';
import {palette, typeRamp} from '../lib/theme';

type SceneProps = {
  section: StorySection;
};

export const IntroSequence: React.FC<SceneProps> = ({section}) => {
  const frame = useCurrentFrame();

  return (
    <SceneFrame kicker={section.kicker} title={section.title} callout={section.callout}>
      <div
        style={{
          flex: 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 48,
        }}
      >
        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            gap: 24,
            transform: `translateY(${slideUp(frame)}px)`,
          }}
        >
          {section.body.map((line, index) => (
            <div
              key={line}
              style={{
                opacity: clampOpacity(frame - index * 8, 0, 14),
                transform: `translateX(${slideRight(frame - index * 8, -36)}px)`,
                fontSize: 44,
                lineHeight: 1.15,
                maxWidth: 760,
                color: index === 0 ? palette.furCream : 'rgba(255,255,255,0.82)',
                fontWeight: index === 0 ? 800 : 500,
              }}
            >
              {line}
            </div>
          ))}
          <div
            style={{
              marginTop: 12,
              alignSelf: 'flex-start',
              padding: '18px 28px',
              borderRadius: 24,
              backgroundColor: 'rgba(0,0,0,0.28)',
              border: '2px solid rgba(255,255,255,0.18)',
              fontFamily: typeRamp.display,
              fontSize: 28,
              fontWeight: 800,
              textTransform: 'uppercase',
              color: palette.blueGlow,
            }}
          >
            Dexter is already judging the audio chain.
          </div>
        </div>
        <div
          style={{
            flex: '0 0 620px',
            display: 'flex',
            justifyContent: 'center',
            opacity: clampOpacity(frame, 0, 16),
          }}
        >
          <BrandBadge size={620} shadowColor="rgba(52, 186, 248, 0.45)" />
        </div>
      </div>
    </SceneFrame>
  );
};
