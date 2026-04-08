# DexDictate Asset Rename And Placement Guide

## What I Changed

This pass cleaned the `assets` library without touching runtime source code.

- Renamed anonymous exports, timestamp files, and generator-default names into semantic DexDictate asset names.
- Renamed numbered variant sets into stable `__variant_a`, `__variant_b`, and similar suffixes.
- Renamed `assets/for randoms` to `assets/random_cycle` so the folder now says what it actually is.
- Moved exact duplicates into `assets/archive_unused/duplicates/` instead of leaving them in the active pool.
- Left clearly intentional names alone, especially the `dexter_*` onboarding illustration set and the existing icon packs.

## Naming Rules Used

- Surface first, subject second, variant last.
- Existing `DexDictate_` naming was preserved where it was already product-specific.
- Personal `dexter_*` names were not touched.
- Duplicate-number noise like `(1)` and `(2)` was replaced with stable variant suffixes or archived if the file was byte-for-byte identical.

## Preserved As-Is

- `assets/dexdictate-illustrations/dexdictate-illustrations/dexter_*`
- `assets/dexdictate-icon-standard-*.png`
- `assets/DexDictate_CA/*.png`
- `assets/ICON_VARIANTS.md`
- `assets/dexdictate-illustrations/dexdictate-illustration-manifest.md`

## Canonical Placement Decisions

### First onboarding welcome asset

Use:

- `assets/DexDictate_onboarding__welcome_giftbox_open_dexter.png`

Why:

- It is the cleanest still image that shows the dog emerging from the present.
- It reads immediately as a welcome moment rather than a settings, status, or reaction state.
- It fits your instruction exactly: the present-opening dog should be the first onboarding welcome image.

Supporting optional motion pair:

- `assets/DexDictate_onboarding__welcome_giftbox_reveal.mp4`

### Launch intro assets

Primary:

- `assets/DexDictate_launch_intro__roundel_primary.mp4`

Alternate:

- `assets/DexDictate_launch_intro__roundel_alt.mp4`

Why:

- These are clearly intro-specific roundel animations rather than onboarding page art.
- The names now align with how they were described in the project history.

### Random open-cycle pool

Use this folder as the cycle source on each UI open:

- `assets/random_cycle/`

Why:

- The folder now contains the rotation candidates under stable names.
- Numbered variants are normalized.
- Generic generator names are gone.
- Exact duplicates were removed from the active pool.

Tone note:

- The `DexDictate_random_cycle__smiley_mask_splatter__variant_*` trio is more aggressive than the rest of the pool.
- If the default product mood should stay restrained, keep those behind an alternate theme or optional profile rather than the default cycle.

## Key Rename Highlights

### Top-level stills

| Old name | New name | Why | Recommended use |
|---|---|---|---|
| `1775496405406.png` | `DexDictate_brand__roundel_text_badge.png` | Anonymous export; clearly a text-roundel brand badge | Legacy badge reference, docs, comparison |
| `1775517582304.png` | `DexDictate_onboarding__welcome_giftbox_closed.png` | Closed gift box is the pre-reveal welcome setup | Optional onboarding lead-in |
| `1775517639993.png` | `DexDictate_onboarding__welcome_giftbox_open_dexter.png` | The actual reveal frame with Dexter emerging from the present | Primary onboarding welcome still |
| `Gemini_Generated_Image_ixjxxcixjxxcixjx.png` | `DexDictate_marketing__hero_get_started_poster.png` | This is a polished marketing poster, not a raw generator file | Landing or promo mockups |
| `file_0000000037f471fdb551773d310e33de.png` | `DexDictate_marketing__welcome_card.png` | Reads like a welcome-card concept | Marketing, readme, deck material |
| `file_00000000e44c71f88a66b10591583160.png` | `DexDictate_marketing__desk_headphones_podcast.png` | Desk scene with laptop, mic, and headphones | Marketing/supporting illustration |
| `grok_image_1775521789981.jpg` | `DexDictate_portrait__headphones_front.jpg` | Straight portrait asset | Profile art or alt branding |
| `grok_image_1775521842723.jpg` | `DexDictate_portrait__headphones_keyboard__variant_a.jpg` | Keyboard portrait variant | Secondary profile art |
| `grok_image_1775521844329.jpg` | `DexDictate_portrait__headphones_keyboard__variant_b.jpg` | Alternate keyboard portrait | Secondary profile art |

### Motion assets

| Old name(s) | New name(s) | Why | Recommended use |
|---|---|---|---|
| `Welcome_to_dexdictate.mp4` | `DexDictate_onboarding__welcome_giftbox_reveal.mp4` | Clear welcome reveal animation | Optional onboarding motion |
| `DexDictate_getsstarted.mp4` | `DexDictate_onboarding__headphones_adjust.mp4` | Animation reads as setup/readiness, not a vague "gets started" label | Permissions/audio setup support |
| `DexDictate_readykeyboard.mp4` | `DexDictate_shortcut__ready_tail_swipe.mp4` | Existing name was vague; the animation reads like a readiness cue | Shortcut/setup support |
| `Dexdictate_greencheck.mp4` | `DexDictate_completion__green_check.mp4` | Completion animation | Onboarding completion |
| `Dexdictate_inputselect.mp4` | `DexDictate_input_selection__red_button_prompt.mp4` | Clearly a prompt/selection motif | Shortcut or trigger selection |
| `Dexdictate_smiley.mp4` | `DexDictate_reaction__smiley_badge.mp4` | Reaction asset, not a product state | Optional flavor asset |
| `into_animation.mp4` | `DexDictate_launch_intro__roundel_primary.mp4` | Primary launch intro source | Launch intro |
| `grok-video-4c77a3a4-ef43-4e4f-a620-db0b57a5025d (1).mp4` | `DexDictate_launch_intro__roundel_alt.mp4` | Alternate launch intro source | Optional alternate intro |
| `grok_video_2026-04-06-19-24-09/12/59.mp4` | `DexDictate_onboarding__welcome_giftbox_closed__variant_a/b/c.mp4` | Same gift-box concept, now grouped coherently | Optional onboarding variants |
| `grok_video_2026-04-06-19-43-32/44-51/45-51.mp4` | `DexDictate_reaction__smiley_badge__variant_a/b/c.mp4` | Same reaction family, now grouped coherently | Optional flavor variants |
| `grok_video_2026-04-06-19-53-34/54-41/56-08.mp4` | `DexDictate_input_selection__red_button_prompt__variant_a/b/c.mp4` | Same selection prompt family | Optional shortcut-selection variants |

### Random cycle folder

The old random folder is now:

- `assets/random_cycle/`

What changed there:

- Generic `grok_image_*` names became explicit pose names.
- Numbered groups became stable variant families.
- Single-file numbered names were normalized.
- Exact duplicate carry-overs were moved out of the active pool, including duplicates that would have overweighted the random cycle.

Notable random-cycle families:

- `DexDictate_onboarding__welcome__variant_a/b.png`
- `DexDictate_onboarding__shortcut_selection__variant_a/b.png`
- `DexDictate_listening__waiting__variant_a/b/c.png`
- `DexDictate_processing__typing__variant_a/b/c.png`
- `DexDictate_result_feedback_badge__variant_a/b.png`
- `DexDictate_random_cycle__standing_pose__variant_a/b/c.jpg`
- `DexDictate_random_cycle__side_eye_pose__variant_a/b/c.jpg`
- `DexDictate_random_cycle__headphones_portrait.jpg`
- `DexDictate_random_cycle__red_button_prompt.jpg`
- `DexDictate_random_cycle__smiley_mask_splatter__variant_a/b/c.jpg`

## Duplicate Handling

Exact duplicates were moved here:

- `assets/archive_unused/duplicates/`

Why:

- Duplicates distort any future random cycle by overweighting identical art.
- Keeping them nearby but out of the active pool preserves provenance without cluttering the usable set.

## Recommended Next Wiring

If you want the app behavior to match the new structure exactly:

1. Point the onboarding welcome screen at `DexDictate_onboarding__welcome_giftbox_open_dexter.png`.
2. Treat `assets/random_cycle/` as the rotation source for the UI-open random cycle.
3. Ignore `assets/archive_unused/duplicates/` when building any runtime asset pool.
4. Consider excluding the `smiley_mask_splatter` trio from the default rotation unless you want a deliberately sharper tone.

## Short Version

- The welcome asset is now obvious.
- The random folder is now a real rotation pool.
- The anonymous garbage names are gone.
- The personally named Dexter assets remain untouched.
