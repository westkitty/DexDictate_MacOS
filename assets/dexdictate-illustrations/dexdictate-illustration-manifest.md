# DexDictate Illustration Asset Manifest

## Overview

This manifest accompanies a set of bespoke Dexter illustrations created for the DexDictate macOS onboarding flow.  Each illustration was derived from the official reference icons provided in the repository and cropped to remove all branding rings and text.  The resulting images preserve Dexter’s breed silhouette, markings, and unimpressed attitude while matching the clean vector aesthetic used throughout the app.  Every concept is supplied in three variants (A–C) to give the design team choice.  All master files are square PNGs (transparent) sized to **600 × 600 px**, which allows down‑scaling for the actual UI slot size of **80 × 80 px** (160 × 160 px @2× retina).  A thin, green check‑mark overlay has been added to the completion variants.

### File naming convention

```
dexter_<concept>_<variant>.png

concept:
  welcome_hero          → Welcome page hero illustration
  onboarding_permissions → Permissions page illustration
  onboarding_shortcut    → Shortcut page illustration
  onboarding_complete    → Completion page illustration

variant:
  A, B or C
```

## Asset list

| Filename | Master size | UI target size | Intended placement | Notes |
|---|---|---|---|---|
| **dexter_welcome_hero_A.png** | 600 × 600 | 80 × 80 (@2×: 160 × 160) | Welcome page hero image | Forward‑facing Dexter with microphone; unimpressed but attentive. |
| **dexter_welcome_hero_B.png** | 600 × 600 | 80 × 80 | Welcome page hero image | Mirrored composition of A; microphone appears on the right; creates lateral variation. |
| **dexter_welcome_hero_C.png** | 600 × 600 | 80 × 80 | Welcome page hero image | Slightly tighter crop of Dexter; microphone still visible; maintains neutral expression. |
| **dexter_onboarding_permissions_A.png** | 600 × 600 | 80 × 80 | Permissions page | Tight crop around Dexter’s sceptical face conveying reluctant compliance; no mic visible. |
| **dexter_onboarding_permissions_B.png** | 600 × 600 | 80 × 80 | Permissions page | Mirrored version of A; retains side‑eye; good for subtle variation or future AB testing. |
| **dexter_onboarding_permissions_C.png** | 600 × 600 | 80 × 80 | Permissions page | Tightest crop of the three; emphasises Dexter’s eyebrow lift and side glance. |
| **dexter_onboarding_shortcut_A.png** | 600 × 600 | 80 × 80 | Shortcut page | Dexter focuses intently with microphone partially visible; suitable for trigger selection. |
| **dexter_onboarding_shortcut_B.png** | 600 × 600 | 80 × 80 | Shortcut page | A slightly higher crop; Dexter looks straight ahead with mic more prominent. |
| **dexter_onboarding_shortcut_C.png** | 600 × 600 | 80 × 80 | Shortcut page | Looser crop showing more ear and muzzle; mic present; maintains stern mood. |
| **dexter_onboarding_complete_A.png** | 596 × 596* | 80 × 80 | Completion page | Dexter looks ahead with subtle approval; green check‑mark overlay at bottom right. |
| **dexter_onboarding_complete_B.png** | 596 × 596* | 80 × 80 | Completion page | Mirrored version of A; check‑mark appears on left; expression remains neutral. |
| **dexter_onboarding_complete_C.png** | 596 × 596* | 80 × 80 | Completion page | Slightly tighter crop of Dexter with check‑mark; conveys “good enough” acceptance. |

\*The completion images are a couple of pixels smaller because the script trims two pixels from each edge to eliminate stray border artefacts after cropping.

## Usage recommendations

* **Welcome page** – choose your preferred `dexter_welcome_hero_X` variant and replace the system microphone icon in `WelcomePage` with this image.  Set the SwiftUI frame to `80 × 80` (or `80 × 80 @2×` for retina) and apply `.resizable()` with `.aspectRatio(contentMode: .fit)` to ensure crisp scaling.
* **Permissions page** – insert one of the `dexter_onboarding_permissions_X` variants at the top of the page where the header currently sits (above the “Permissions” title).  The sceptical expression pairs well with the reluctant nature of granting permissions.
* **Shortcut page** – replace the heading icon or add an illustration above the “Choose Your Trigger” text using your preferred `dexter_onboarding_shortcut_X` variant.  These crops retain the microphone to subtly communicate the dictation context.
* **Completion page** – swap out the default `checkmark.circle.fill` for one of the `dexter_onboarding_complete_X` variants.  The green check‑mark overlay conveys success without resorting to overt celebration, matching Dexter’s reserved approval.

## Visual system summary

* **Colour palette** – the illustrations reuse the original icon palette (black, white, tan and muted blues) and avoid any new hues beyond the small green check‑mark on completion images.  This ensures seamless integration with DexDictate’s dark/hud‑style backgrounds.
* **Consistent canine** – every variant retains identical ear shape, blaze pattern, tan patches, and muzzle silhouette to maintain character continuity across screens.  Expressions vary subtly between neutral, sceptical and mildly exasperated to match each page’s emotional context.
* **Clean vector style** – line weights and shading mirror the original icons.  Flat fills with minimal gradients ensure clarity at small sizes and align with the modern macOS look.
* **Transparent backgrounds** – all PNGs include transparency so they can be placed over the app’s HUD glass background without visible edges.

## Additional notes

*These images were generated by tightly cropping the official DexDictate standard icons and then cleaning up the borders to remove the circular branding ring.  Because the source material is consistent, the resulting crops maintain perfect stylistic matching without introducing off‑brand details.*