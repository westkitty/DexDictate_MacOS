import type {StorySection} from '../data/video-data';

const WORDS_PER_SECOND = 2.7;
const MIN_SECTION_SECONDS = 3.6;
const MAX_SECTION_SECONDS = 7.4;
const SECTION_BUFFER_FRAMES = 26;
const BODY_LINE_BONUS = 10;
const END_HOLD_FRAMES = 20;

const countWords = (value: string) => value.trim().split(/\s+/).filter(Boolean).length;

export const getSectionDurationInFrames = (section: StorySection, fps: number) => {
  const totalWords = countWords(
    [section.kicker, section.title, section.callout, ...section.body].join(' '),
  );
  const textFrames = Math.round((totalWords / WORDS_PER_SECOND) * fps);
  const sectionFrames = textFrames + SECTION_BUFFER_FRAMES + section.body.length * BODY_LINE_BONUS;

  return Math.max(
    Math.round(MIN_SECTION_SECONDS * fps),
    Math.min(Math.round(MAX_SECTION_SECONDS * fps), sectionFrames),
  );
};

export const getSectionDurations = (sections: StorySection[], fps: number) => {
  return sections.map((section) => getSectionDurationInFrames(section, fps));
};

export const getSectionOffsets = (durations: number[]) => {
  let runningTotal = 0;

  return durations.map((duration) => {
    const current = runningTotal;
    runningTotal += duration;
    return current;
  });
};

export const getTotalDurationInFrames = (sections: StorySection[], fps: number) => {
  return getSectionDurations(sections, fps).reduce((sum, duration) => sum + duration, 0) + END_HOLD_FRAMES;
};
