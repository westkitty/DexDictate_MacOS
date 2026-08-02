import React from 'react';
import {useCurrentFrame} from 'remotion';
import {BrandBadge} from '../components/BrandBadge';
import {SceneFrame} from '../components/SceneFrame';
import type {StorySection} from '../data/video-data';
import {clampOpacity, slideUp} from '../lib/motion';
import {palette, typeRamp} from '../lib/theme';

type SceneProps = {
  section: StorySection;
  brandName: string;
  tagline: string;
};

export const ClosingSequence: React.FC<SceneProps> = ({section, brandName, tagline}) => {
  const frame = useCurrentFrame();

  return (
    <SceneFrame kicker={section.kicker} title={section.title} callout={section.callout}>
      <div
        style={{
          flex: 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 56,
        }}
      >
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 22,
            transform: `translateY(${slideUp(frame, 28)}px)`,
            maxWidth: 760,
          }}
        >
          <div
            style={{
              fontFamily: typeRamp.display,
              fontSize: 128,
              lineHeight: 0.9,
              fontWeight: 900,
              textTransform: 'uppercase',
              color: palette.white,
            }}
          >
            {brandName}
          </div>
          <div style={{fontSize: 38, lineHeight: 1.2, color: palette.furCream}}>{tagline}</div>
          {section.body.map((line, index) => (
            <div
              key={line}
              style={{
                opacity: clampOpacity(frame - 8 - index * 6, 0, 12),
                fontSize: 30,
                lineHeight: 1.24,
                color: 'rgba(255,255,255,0.82)',
              }}
            >
              {line}
            </div>
          ))}
          <div
            style={{
              marginTop: 14,
              alignSelf: 'flex-start',
              padding: '18px 24px',
              borderRadius: 999,
              backgroundColor: 'rgba(255,255,255,0.08)',
              border: '2px solid rgba(255,255,255,0.14)',
              fontWeight: 800,
            }}
          >
            Speak clearly. Stay local. Impress the dog.
          </div>
        </div>
        <BrandBadge size={520} shadowColor="rgba(52, 186, 248, 0.38)" />
      </div>
    </SceneFrame>
  );
};
