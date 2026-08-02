import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig} from 'remotion';
import {clampOpacity, drift} from '../lib/motion';
import {palette, typeRamp} from '../lib/theme';

type SceneFrameProps = {
  kicker: string;
  title: string;
  callout: string;
  children: React.ReactNode;
};

export const SceneFrame: React.FC<SceneFrameProps> = ({kicker, title, callout, children}) => {
  const frame = useCurrentFrame();
  const {width, height, durationInFrames} = useVideoConfig();
  const opacity = clampOpacity(frame, 0, 16);
  const outroOpacity = clampOpacity(durationInFrames - frame, 0, 14);
  const compositeOpacity = Math.min(opacity, outroOpacity);
  const haloDrift = drift(frame, 18, 0.45);

  return (
    <AbsoluteFill
      style={{
        opacity: compositeOpacity,
        background: `radial-gradient(circle at 20% 18%, rgba(128,221,255,0.35), transparent 28%), radial-gradient(circle at 80% 14%, rgba(255,255,255,0.16), transparent 22%), linear-gradient(140deg, ${palette.ink} 0%, #0b1820 40%, ${palette.blueDeep} 100%)`,
        color: palette.white,
        fontFamily: typeRamp.body,
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.06) 1px, transparent 1px)',
          backgroundSize: `${width * 0.04}px ${width * 0.04}px`,
          opacity: 0.18,
        }}
      />
      <div
        style={{
          position: 'absolute',
          top: height * 0.08 + haloDrift,
          right: width * 0.07,
          width: width * 0.24,
          height: width * 0.24,
          borderRadius: '50%',
          border: '2px solid rgba(255,255,255,0.18)',
          boxShadow: '0 0 0 18px rgba(52,186,248,0.08), 0 0 0 42px rgba(52,186,248,0.05)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: width * 0.06,
          right: width * 0.06,
          top: height * 0.07,
          bottom: height * 0.07,
          display: 'flex',
          flexDirection: 'column',
          gap: height * 0.035,
        }}
      >
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 14,
            maxWidth: width * 0.6,
          }}
        >
          <div
            style={{
              alignSelf: 'flex-start',
              padding: '12px 24px',
              borderRadius: 999,
              backgroundColor: 'rgba(255,255,255,0.12)',
              border: '2px solid rgba(255,255,255,0.18)',
              fontWeight: 800,
              letterSpacing: '0.08em',
              textTransform: 'uppercase',
              color: palette.blueGlow,
            }}
          >
            {kicker}
          </div>
          <div
            style={{
              fontFamily: typeRamp.display,
              fontSize: width * 0.06,
              fontWeight: 900,
              lineHeight: 0.9,
              letterSpacing: '-0.03em',
              textTransform: 'uppercase',
              textShadow: '0 10px 30px rgba(0,0,0,0.3)',
            }}
          >
            {title}
          </div>
          <div
            style={{
              maxWidth: width * 0.5,
              fontSize: width * 0.018,
              lineHeight: 1.35,
              color: 'rgba(255,255,255,0.84)',
            }}
          >
            {callout}
          </div>
        </div>
        <div style={{flex: 1, display: 'flex'}}>{children}</div>
      </div>
    </AbsoluteFill>
  );
};
