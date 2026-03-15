import React from 'react';
import {useCurrentFrame} from 'remotion';
import {SceneFrame} from '../components/SceneFrame';
import type {StorySection} from '../data/video-data';
import {clampOpacity, slideRight, slideUp} from '../lib/motion';
import {palette, typeRamp} from '../lib/theme';

type SceneProps = {
  section: StorySection;
};

const spokenWords = ['Welcome', 'to', 'DexDictate'];

export const UsageSequence: React.FC<SceneProps> = ({section}) => {
  const frame = useCurrentFrame();
  const meterHeight = 100 + Math.abs(Math.sin(frame / 5)) * 120;
  const textProgress = Math.min(spokenWords.length, Math.floor(frame / 18) + 1);

  return (
    <SceneFrame kicker={section.kicker} title={section.title} callout={section.callout}>
      <div
        style={{
          flex: 1,
          display: 'grid',
          gridTemplateColumns: '0.9fr 1.1fr',
          gap: 32,
          alignItems: 'stretch',
        }}
      >
        <div
          style={{
            backgroundColor: 'rgba(255,255,255,0.08)',
            borderRadius: 36,
            border: '2px solid rgba(255,255,255,0.14)',
            padding: 28,
            display: 'flex',
            flexDirection: 'column',
            gap: 22,
            transform: `translateY(${slideUp(frame, 24)}px)`,
          }}
        >
          <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center'}}>
            <div style={{fontWeight: 800, fontSize: 32}}>DexDictate live input</div>
            <div
              style={{
                padding: '10px 16px',
                borderRadius: 999,
                backgroundColor: 'rgba(133,217,159,0.16)',
                border: '2px solid rgba(133,217,159,0.32)',
                fontWeight: 800,
              }}
            >
              Listening
            </div>
          </div>
          <div
            style={{
              flex: 1,
              borderRadius: 28,
              backgroundColor: 'rgba(0,0,0,0.32)',
              padding: 24,
              display: 'flex',
              alignItems: 'flex-end',
              gap: 14,
            }}
          >
            {Array.from({length: 9}).map((_, index) => {
              const height = 72 + Math.abs(Math.sin(frame / 4 + index)) * meterHeight * (0.35 + index * 0.03);
              return (
                <div
                  key={index}
                  style={{
                    flex: 1,
                    height,
                    borderRadius: 999,
                    background: `linear-gradient(180deg, ${palette.blueGlow} 0%, ${palette.blue} 100%)`,
                  }}
                />
              );
            })}
          </div>
          <div
            style={{
              padding: '18px 20px',
              borderRadius: 24,
              backgroundColor: 'rgba(255,255,255,0.08)',
              fontSize: 30,
              color: palette.furCream,
            }}
          >
            Partial transcript: “Welcome to DexDictate”
          </div>
        </div>
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 22,
            transform: `translateX(${slideRight(frame, 28)}px)`,
          }}
        >
          <div
            style={{
              flex: 1,
              backgroundColor: 'rgba(248,241,225,0.96)',
              color: palette.charcoal,
              borderRadius: 36,
              padding: 34,
              display: 'flex',
              flexDirection: 'column',
              gap: 20,
              boxShadow: '0 28px 80px rgba(0,0,0,0.16)',
            }}
          >
            <div style={{fontFamily: typeRamp.display, fontSize: 40, fontWeight: 900}}>Frontmost App</div>
            <div style={{fontSize: 34, lineHeight: 1.35}}>
              {spokenWords.slice(0, textProgress).join(' ')}
              <span
                style={{
                  opacity: Math.sin(frame / 4) > 0 ? 1 : 0.2,
                  color: palette.blueDeep,
                }}
              >
                |
              </span>
            </div>
            <div
              style={{
                marginTop: 'auto',
                padding: '16px 20px',
                borderRadius: 18,
                backgroundColor: 'rgba(11,124,189,0.1)',
                fontSize: 26,
                fontWeight: 700,
              }}
            >
              Auto-paste ready. No ceremonial nonsense required.
            </div>
          </div>
          <div style={{display: 'flex', gap: 18}}>
            {section.body.map((line, index) => (
              <div
                key={line}
                style={{
                  flex: 1,
                  padding: '18px 20px',
                  borderRadius: 22,
                  backgroundColor: 'rgba(255,255,255,0.08)',
                  border: '2px solid rgba(255,255,255,0.14)',
                  opacity: clampOpacity(frame - 14 - index * 7, 0, 10),
                  fontSize: 26,
                  lineHeight: 1.24,
                }}
              >
                {line}
              </div>
            ))}
          </div>
        </div>
      </div>
    </SceneFrame>
  );
};
