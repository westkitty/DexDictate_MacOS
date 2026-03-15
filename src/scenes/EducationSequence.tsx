import React from 'react';
import {useCurrentFrame} from 'remotion';
import {SceneFrame} from '../components/SceneFrame';
import type {StorySection} from '../data/video-data';
import {clampOpacity, slideUp} from '../lib/motion';
import {palette} from '../lib/theme';

type SceneProps = {
  section: StorySection;
};

const checklist = [
  {label: 'Microphone', state: 'Ready', color: palette.green},
  {label: 'Accessibility', state: 'Needs review', color: palette.furTan},
  {label: 'Input Monitoring', state: 'Guide user', color: palette.blueGlow},
];

export const EducationSequence: React.FC<SceneProps> = ({section}) => {
  const frame = useCurrentFrame();

  return (
    <SceneFrame kicker={section.kicker} title={section.title} callout={section.callout}>
      <div
        style={{
          flex: 1,
          display: 'grid',
          gridTemplateColumns: '1.05fr 0.95fr',
          gap: 28,
          alignItems: 'stretch',
        }}
      >
        <div
          style={{
            backgroundColor: 'rgba(255,255,255,0.08)',
            borderRadius: 34,
            border: '2px solid rgba(255,255,255,0.14)',
            padding: 30,
            display: 'flex',
            flexDirection: 'column',
            gap: 18,
            transform: `translateY(${slideUp(frame, 22)}px)`,
          }}
        >
          <div style={{fontSize: 36, fontWeight: 800}}>Onboarding guidance</div>
          {checklist.map((item, index) => (
            <div
              key={item.label}
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                padding: '22px 24px',
                borderRadius: 24,
                backgroundColor: 'rgba(0,0,0,0.24)',
                border: '2px solid rgba(255,255,255,0.12)',
                opacity: clampOpacity(frame - index * 6, 0, 14),
              }}
            >
              <div style={{fontSize: 30, fontWeight: 700}}>{item.label}</div>
              <div
                style={{
                  padding: '10px 16px',
                  borderRadius: 999,
                  backgroundColor: `${item.color}22`,
                  border: `2px solid ${item.color}66`,
                  color: item.color,
                  fontWeight: 800,
                }}
              >
                {item.state}
              </div>
            </div>
          ))}
          <div
            style={{
              marginTop: 'auto',
              padding: '18px 20px',
              borderRadius: 22,
              backgroundColor: 'rgba(133,217,159,0.12)',
              border: '2px solid rgba(133,217,159,0.3)',
              fontSize: 26,
              lineHeight: 1.28,
            }}
          >
            The point is simple: the product explains the next step instead of quietly failing and blaming the user.
          </div>
        </div>
        <div style={{display: 'flex', flexDirection: 'column', gap: 18}}>
          {section.body.map((line, index) => (
            <div
              key={line}
              style={{
                flex: 1,
                padding: '28px 30px',
                borderRadius: 30,
                backgroundColor: index === 0 ? 'rgba(52,186,248,0.14)' : 'rgba(255,255,255,0.08)',
                border: '2px solid rgba(255,255,255,0.14)',
                opacity: clampOpacity(frame - 10 - index * 8, 0, 12),
                display: 'flex',
                alignItems: 'center',
                fontSize: 30,
                lineHeight: 1.26,
              }}
            >
              {line}
            </div>
          ))}
          <div
            style={{
              padding: '18px 22px',
              borderRadius: 22,
              backgroundColor: 'rgba(0,0,0,0.28)',
              border: '2px solid rgba(255,255,255,0.12)',
              fontSize: 24,
              lineHeight: 1.35,
              opacity: clampOpacity(frame - 20, 0, 12),
            }}
          >
            Education here means clear onboarding, permission context, and signals that help a new user recover quickly.
          </div>
        </div>
      </div>
    </SceneFrame>
  );
};
