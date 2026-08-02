export const DEFAULT_WIDTH = 1920;
export const DEFAULT_HEIGHT = 1080;
export const DEFAULT_FPS = 30;

export type StorySection = {
  id:
    | 'intro'
    | 'promise'
    | 'install'
    | 'usage'
    | 'education'
    | 'dexter'
    | 'closing';
  kicker: string;
  title: string;
  callout: string;
  body: string[];
};

export type MainCompositionProps = {
  brandName: string;
  tagline: string;
  installCommand: string;
  launchCommand: string;
  sections: StorySection[];
};

export const getMainCompositionProps = (): MainCompositionProps => ({
  brandName: 'DexDictate',
  tagline: 'Privacy-first dictation for macOS',
  installCommand: 'INSTALL_DIR=/Applications ./build.sh',
  launchCommand: 'open /Applications/DexDictate.app',
  sections: [
    {
      id: 'intro',
      kicker: 'Welcome',
      title: 'Meet DexDictate',
      callout: 'A local dictation bridge for macOS',
      body: [
        'Welcome to DexDictate.',
        'Dexter introduces a tool built to turn speech into usable text without sending audio off the machine.',
      ],
    },
    {
      id: 'promise',
      kicker: 'Core Promise',
      title: 'Speak Clearly. Stay Local.',
      callout: 'On-device capture, transcription, and paste-ready output',
      body: [
        'DexDictate lives in the menu bar and keeps the whole flow on your Mac.',
        'You talk, it transcribes locally, and your words land where you need them.',
      ],
    },
    {
      id: 'install',
      kicker: 'Install',
      title: 'Set It Up Fast',
      callout: 'Build, install, launch',
      body: [
        'Get the app installed from source in a short sequence.',
        'Build into Applications, open the app, and you are ready for first run.',
      ],
    },
    {
      id: 'usage',
      kicker: 'How It Works',
      title: 'Press. Speak. Insert.',
      callout: 'Live feedback makes the workflow obvious',
      body: [
        'Trigger dictation, speak naturally, watch the live meter respond, and see text arrive in the frontmost app.',
        'The value is not abstract. It is immediate.',
      ],
    },
    {
      id: 'education',
      kicker: 'Guidance',
      title: 'The Education Flow Helps',
      callout: 'Onboarding and permission guidance reduce confusion',
      body: [
        'DexDictate teaches the next step instead of leaving people to guess.',
        'The onboarding surfaces missing permissions, readiness, and what to fix first.',
      ],
    },
    {
      id: 'dexter',
      kicker: 'Why Dexter',
      title: 'Dexter Is the Quality Bar',
      callout: 'Unimpressed on purpose',
      body: [
        'Dexter is the mascot, but more importantly he represents scrutiny, correctness, and a refusal to accept sloppy behavior.',
        'If Dexter approves, the product has done its job properly.',
      ],
    },
    {
      id: 'closing',
      kicker: 'Finish',
      title: 'Talk Better. Work Faster.',
      callout: 'DexDictate, with Dexter watching closely',
      body: [
        'DexDictate helps people speak into their Mac workflow with privacy and clarity intact.',
        'The last thing on screen should feel like the icon came to life and explained itself.',
      ],
    },
  ],
});
