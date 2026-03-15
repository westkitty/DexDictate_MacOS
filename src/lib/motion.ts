import {Easing, interpolate, spring} from 'remotion';

export const clampOpacity = (frame: number, inFrame: number, outFrame: number) => {
  return interpolate(frame, [inFrame, outFrame], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
};

export const slideUp = (frame: number, from = 44, duration = 18) => {
  return interpolate(frame, [0, duration], [from, 0], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
};

export const slideRight = (frame: number, from = -64, duration = 22) => {
  return interpolate(frame, [0, duration], [from, 0], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
};

export const pulseScale = (frame: number, fps: number, delay = 0) => {
  return interpolate(
    spring({
      frame: frame - delay,
      fps,
      durationInFrames: 28,
      config: {damping: 18, stiffness: 160},
    }),
    [0, 1],
    [0.84, 1],
  );
};

export const drift = (frame: number, amplitude: number, speed = 1) => {
  return Math.sin((frame / 18) * speed) * amplitude;
};
