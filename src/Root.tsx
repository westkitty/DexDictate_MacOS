import {Composition} from 'remotion';
import {MainComposition} from './compositions/MainComposition';
import {
  DEFAULT_FPS,
  DEFAULT_HEIGHT,
  DEFAULT_WIDTH,
  getMainCompositionProps,
  type MainCompositionProps,
} from './data/video-data';
import {getTotalDurationInFrames} from './lib/timing';

const defaultProps = getMainCompositionProps();

export const RemotionRoot = () => {
  return (
    <Composition
      id="MainComposition"
      component={MainComposition}
      width={DEFAULT_WIDTH}
      height={DEFAULT_HEIGHT}
      fps={DEFAULT_FPS}
      durationInFrames={getTotalDurationInFrames(defaultProps.sections, DEFAULT_FPS)}
      defaultProps={defaultProps satisfies MainCompositionProps}
      calculateMetadata={({props}) => ({
        durationInFrames: getTotalDurationInFrames(props.sections, DEFAULT_FPS),
      })}
    />
  );
};
