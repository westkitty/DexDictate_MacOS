import React from 'react';
import {useCurrentFrame, useVideoConfig} from 'remotion';
import {BrandBadge} from '../components/BrandBadge';
import {SceneFrame} from '../components/SceneFrame';
import type {StorySection} from '../data/video-data';
import {clampOpacity, drift, slideUp} from '../lib/motion';
import {palette, typeRamp} from '../lib/theme';

type SceneProps = {
  section: StorySection;
};

const flowLabels = ['Speak', 'DexDictate', 'Text'];

export const PromiseSequence: React.FC<SceneProps> = ({section}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  return (
    <SceneFrame kicker={section.kicker} title={section.title} callout={section.callout}>
      <div
        style={{
          flex: 1,
          display: 'grid',
          gridTemplateColumns: '0.92fr 1.08fr',
          gap: 40,
          alignItems: 'center',
        }}
      >
        <div style={{display: 'flex', justifyContent: 'center'}}>
          <BrandBadge size={470} shadowColor="rgba(255, 255, 255, 0.28)" />
        </div>
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 28,
            transform: `translateY(${slideUp(frame, 28)}px)`,
          }}
        >
          <div style={{display: 'flex', gap: 18, alignItems: 'center'}}>
            {flowLabels.map((label, index) => (
              <React.Fragment key={label}>
                <div
                  style={{
                    flex: 1,
                    padding: '24px 22px',
                    borderRadius: 28,
                    backgroundColor: index === 1 ? 'rgba(52,186,248,0.22)' : 'rgba(255,255,255,0.08)',
                    border: '2px solid rgba(255,255,255,0.16)',
                    opacity: clampOpacity(frame - index * 6, 0, 14),
                    textAlign: 'center',
                    fontFamily: typeRamp.display,
                    fontWeight: 900,
                    fontSize: 32,
                    textTransform: 'uppercase',
                  }}
                >
                  {label}
                </div>
                {index < flowLabels.length - 1 ? (
                  <div
                    style={{
                      fontSize: 42,
                      fontWeight: 900,
                      color: palette.blueGlow,
                    }}
                  >
                    →
                  </div>
                ) : null}
              </React.Fragment>
            ))}
          </div>
          <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 22}}>
            {section.body.map((line, index) => (
              <div
                key={line}
                style={{
                  minHeight: 172,
                  padding: '26px 28px',
                  borderRadius: 30,
                  backgroundColor: 'rgba(0,0,0,0.25)',
                  border: '2px solid rgba(255,255,255,0.14)',
                  opacity: clampOpacity(frame - 8 - index * 7, 0, 14),
                  display: 'flex',
                  alignItems: 'center',
                  fontSize: 32,
                  lineHeight: 1.2,
                }}
              >
                {line}
              </div>
            ))}
          </div>
          <div
            style={{
              display: 'flex',
              gap: 18,
              alignItems: 'center',
            }}
          >
            {['Local audio', 'Local Whisper', 'No cloud detour'].map((pill, index) => (
              <div
                key={pill}
                style={{
                  padding: '16px 22px',
                  borderRadius: 999,
                  backgroundColor: 'rgba(133,217,159,0.15)',
                  border: '2px solid rgba(133,217,159,0.35)',
                  fontWeight: 800,
                  opacity: clampOpacity(frame - 18 - index * 4, 0, 10),
                  transform: `translateY(${drift(frame + index * fps, 6, 0.55)}px)`,
                }}
              >
                {pill}
              </div>
            ))}
          </div>
        </div>
      </div>
    </SceneFrame>
  );
};
