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

const traits = ['Ungovernable', 'Sharp-eyed', 'Dependable'];

export const DexterSequence: React.FC<SceneProps> = ({section}) => {
  const frame = useCurrentFrame();

  return (
    <SceneFrame kicker={section.kicker} title={section.title} callout={section.callout}>
      <div
        style={{
          flex: 1,
          display: 'grid',
          gridTemplateColumns: '0.9fr 1.1fr',
          gap: 36,
          alignItems: 'center',
        }}
      >
        <div style={{display: 'flex', justifyContent: 'center'}}>
          <BrandBadge size={500} shadowColor="rgba(0, 0, 0, 0.45)" />
        </div>
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 20,
            transform: `translateY(${slideUp(frame, 24)}px)`,
          }}
        >
          <div
            style={{
              padding: '24px 28px',
              borderRadius: 28,
              backgroundColor: 'rgba(255,255,255,0.08)',
              border: '2px solid rgba(255,255,255,0.14)',
              fontSize: 34,
              lineHeight: 1.18,
              color: palette.furCream,
              transform: `translateX(${slideRight(frame, -28)}px)`,
            }}
          >
            Dexter is not decorative brand foam. He stands for scrutiny, standards, and a small amount of perfectly justified impatience.
          </div>
          <div style={{display: 'flex', gap: 16}}>
            {traits.map((trait, index) => (
              <div
                key={trait}
                style={{
                  flex: 1,
                  padding: '18px 16px',
                  borderRadius: 22,
                  textAlign: 'center',
                  backgroundColor: 'rgba(0,0,0,0.26)',
                  border: '2px solid rgba(255,255,255,0.12)',
                  fontFamily: typeRamp.display,
                  fontSize: 26,
                  fontWeight: 900,
                  textTransform: 'uppercase',
                  opacity: clampOpacity(frame - 8 - index * 5, 0, 12),
                }}
              >
                {trait}
              </div>
            ))}
          </div>
          {section.body.map((line, index) => (
            <div
              key={line}
              style={{
                padding: '22px 24px',
                borderRadius: 22,
                backgroundColor: index === 0 ? 'rgba(199,140,73,0.18)' : 'rgba(255,255,255,0.08)',
                border: '2px solid rgba(255,255,255,0.12)',
                opacity: clampOpacity(frame - 16 - index * 6, 0, 10),
                fontSize: 28,
                lineHeight: 1.26,
              }}
            >
              {line}
            </div>
          ))}
        </div>
      </div>
    </SceneFrame>
  );
};
