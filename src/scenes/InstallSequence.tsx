import React from 'react';
import {useCurrentFrame} from 'remotion';
import {SceneFrame} from '../components/SceneFrame';
import type {StorySection} from '../data/video-data';
import {clampOpacity, slideUp} from '../lib/motion';
import {palette, typeRamp} from '../lib/theme';

type SceneProps = {
  section: StorySection;
  installCommand: string;
  launchCommand: string;
};

const steps = [
  {step: '1', label: 'Clone the repo', value: 'git clone https://github.com/WestKitty/DexDictate_MacOS.git'},
  {step: '2', label: 'Build into Applications', value: 'INSTALL_DIR=/Applications ./build.sh'},
  {step: '3', label: 'Launch the app', value: 'open /Applications/DexDictate.app'},
];

export const InstallSequence: React.FC<SceneProps> = ({section, installCommand, launchCommand}) => {
  const frame = useCurrentFrame();

  const renderedSteps = steps.map((step) =>
    step.step === '2' ? {...step, value: installCommand} : step.step === '3' ? {...step, value: launchCommand} : step,
  );

  return (
    <SceneFrame kicker={section.kicker} title={section.title} callout={section.callout}>
      <div style={{flex: 1, display: 'flex', flexDirection: 'column', gap: 24}}>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 24,
            flex: 1,
          }}
        >
          {renderedSteps.map((step, index) => (
            <div
              key={step.step}
              style={{
                transform: `translateY(${slideUp(frame - index * 7, 34)}px)`,
                opacity: clampOpacity(frame - index * 7, 0, 14),
                backgroundColor: 'rgba(8,10,14,0.62)',
                borderRadius: 32,
                border: '2px solid rgba(255,255,255,0.14)',
                padding: 30,
                display: 'flex',
                flexDirection: 'column',
                gap: 24,
                boxShadow: '0 24px 70px rgba(0,0,0,0.18)',
              }}
            >
              <div
                style={{
                  width: 62,
                  height: 62,
                  borderRadius: 31,
                  backgroundColor: 'rgba(52,186,248,0.16)',
                  border: '2px solid rgba(52,186,248,0.42)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontFamily: typeRamp.display,
                  fontSize: 34,
                  fontWeight: 900,
                }}
              >
                {step.step}
              </div>
              <div style={{fontSize: 34, fontWeight: 800}}>{step.label}</div>
              <div
                style={{
                  padding: '20px 18px',
                  borderRadius: 22,
                  backgroundColor: 'rgba(255,255,255,0.07)',
                  border: '1px solid rgba(255,255,255,0.14)',
                  color: palette.furCream,
                  fontFamily: 'Menlo, Monaco, monospace',
                  fontSize: 24,
                  lineHeight: 1.35,
                }}
              >
                {step.value}
              </div>
            </div>
          ))}
        </div>
        <div style={{display: 'flex', gap: 20}}>
          {section.body.map((line, index) => (
            <div
              key={line}
              style={{
                flex: 1,
                padding: '22px 26px',
                borderRadius: 22,
                backgroundColor: 'rgba(255,255,255,0.08)',
                border: '2px solid rgba(255,255,255,0.12)',
                opacity: clampOpacity(frame - 16 - index * 5, 0, 10),
                fontSize: 28,
                lineHeight: 1.24,
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
