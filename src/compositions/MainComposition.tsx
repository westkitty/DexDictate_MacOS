import React from 'react';
import {AbsoluteFill, Sequence, useVideoConfig} from 'remotion';
import {type MainCompositionProps} from '../data/video-data';
import {getSectionDurations, getSectionOffsets} from '../lib/timing';
import {ClosingSequence} from '../scenes/ClosingSequence';
import {DexterSequence} from '../scenes/DexterSequence';
import {EducationSequence} from '../scenes/EducationSequence';
import {InstallSequence} from '../scenes/InstallSequence';
import {IntroSequence} from '../scenes/IntroSequence';
import {PromiseSequence} from '../scenes/PromiseSequence';
import {UsageSequence} from '../scenes/UsageSequence';

export const MainComposition: React.FC<MainCompositionProps> = ({
  brandName,
  tagline,
  installCommand,
  launchCommand,
  sections,
}) => {
  const {fps} = useVideoConfig();
  const durations = getSectionDurations(sections, fps);
  const offsets = getSectionOffsets(durations);

  return (
    <AbsoluteFill style={{backgroundColor: '#050608'}}>
      {sections.map((section, index) => {
        const from = offsets[index];
        const durationInFrames = durations[index];

        return (
          <Sequence key={section.id} from={from} durationInFrames={durationInFrames}>
            {section.id === 'intro' ? <IntroSequence section={section} /> : null}
            {section.id === 'promise' ? <PromiseSequence section={section} /> : null}
            {section.id === 'install' ? (
              <InstallSequence
                section={section}
                installCommand={installCommand}
                launchCommand={launchCommand}
              />
            ) : null}
            {section.id === 'usage' ? <UsageSequence section={section} /> : null}
            {section.id === 'education' ? <EducationSequence section={section} /> : null}
            {section.id === 'dexter' ? <DexterSequence section={section} /> : null}
            {section.id === 'closing' ? (
              <ClosingSequence section={section} brandName={brandName} tagline={tagline} />
            ) : null}
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};
