#!/usr/bin/env python3
"""
Generate watermark placeholder PNGs for DexDictate Help screenshot slots.
Uses existing RandomCycle dog illustrations composited at 30% opacity
on a dark charcoal background — matches the app's visual language.

Skips slots where a PNG already exists (e.g., the captured welcome overview).
Run from anywhere; paths are relative to this script's directory.
"""

import AppKit
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT  = os.path.join(SCRIPT_DIR, "..")
RC_DIR     = os.path.join(REPO_ROOT, "Sources/DexDictateKit/Resources/ProfileAssets/RandomCycle")
OUT_DIR    = os.path.join(REPO_ROOT, "Sources/DexDictateKit/Resources/Assets.xcassets/Help")

# (output_stem, source_filename_stem_in_RandomCycle)
# Source images are 1024×1024 PNG with alpha.
SLOTS = [
    # Getting Started / Onboarding
    ("help-onboarding-permissions",     "DexDictate_onboarding__welcome__variant_a"),
    ("help-onboarding-shortcut",        "DexDictate_onboarding__shortcut_selection__variant_a"),
    # Permissions
    ("help-permissions-banner",         "DexDictate_offline_privacy__variant_a"),
    ("help-permissions-system-settings","DexDictate_app_settings"),
    # Trigger Setup
    ("help-trigger-settings",           "DexDictate_trigger_mode__hold_to_talk__variant_a"),
    # Recording & Audio
    ("help-recording-active",           "DexDictate_active_recording_label__recording"),
    # Transcription
    ("help-transcription-model",        "DexDictate_loading_ai_model"),
    # Output & Pasting
    ("help-output-settings",            "DexDictate_processing__typing__variant_a"),
    # Transcription History
    ("help-history-inline-expanded",    "DexDictate_transcription_history__collapsed"),
    ("help-history-window",             "DexDictate_transcription_history__expanded__variant_a"),
    # Custom Vocabulary
    ("help-vocabulary-correction-sheet","DexDictate_success__saved__variant_a"),
    # Voice Commands
    ("help-voice-commands-sheet",       "DexDictate_mic_only_icon__variant_a"),
    # Appearance & Menu Bar
    ("help-appearance-settings",        "DexDictate_mode__aussie_profile"),
    # Floating HUD
    ("help-floating-hud-states",        "DexDictate_floating_hud_window__variant_a"),
    # Safe Mode
    ("help-safe-mode-toggle",           "DexDictate_offline_privacy__variant_b"),
    # Benchmarking
    ("help-benchmark-capture",          "DexDictate_benchmark__running__variant_a"),
    ("help-model-settings",             "DexDictate_benchmark__running__variant_b"),
    # Diagnostics
    ("help-diagnostics-permissions-banner", "DexDictate_error__misunderstood__variant_a"),
]

# ── output image spec ─────────────────────────────────────────────────────────
OUT_W   = 480
OUT_H   = 300
DOG_OPACITY = 0.30      # 30% — visible but clearly a placeholder, not a screenshot
BG_COLOR = (0.10, 0.105, 0.155, 1.0)   # dark charcoal matching the app gradient

def make_watermark(source_path: str) -> AppKit.NSImage:
    """Composite the dog image at DOG_OPACITY onto a dark charcoal background."""
    out_size = AppKit.NSMakeSize(OUT_W, OUT_H)
    out_img  = AppKit.NSImage.alloc().initWithSize_(out_size)
    out_img.lockFocus()

    # ── background ─────────────────────────────────────────────────────────────
    r, g, b, a = BG_COLOR
    bg = AppKit.NSColor.colorWithSRGBRed_green_blue_alpha_(r, g, b, a)
    bg.set()
    AppKit.NSRectFill(AppKit.NSMakeRect(0, 0, OUT_W, OUT_H))

    # ── dog image centred, scaled to fit, at DOG_OPACITY ──────────────────────
    src = AppKit.NSImage.alloc().initWithContentsOfFile_(source_path)
    if src is None:
        print(f"  ⚠ could not load {source_path}")
        out_img.unlockFocus()
        return out_img

    # Scale to fit within (OUT_W * 0.72) × (OUT_H * 0.86), maintaining 1:1 aspect
    max_dim = min(OUT_W * 0.72, OUT_H * 0.86)
    draw_w  = max_dim
    draw_h  = max_dim
    draw_x  = (OUT_W - draw_w) / 2
    draw_y  = (OUT_H - draw_h) / 2 + 4   # slight upward nudge

    src.drawInRect_fromRect_operation_fraction_(
        AppKit.NSMakeRect(draw_x, draw_y, draw_w, draw_h),
        AppKit.NSZeroRect,
        AppKit.NSCompositingOperationSourceOver,
        DOG_OPACITY,
    )

    out_img.unlockFocus()
    return out_img


def save_png(image: AppKit.NSImage, path: str) -> None:
    tiff     = image.TIFFRepresentation()
    bitmap   = AppKit.NSBitmapImageRep.imageRepWithData_(tiff)
    png_data = bitmap.representationUsingType_properties_(
        AppKit.NSBitmapImageFileTypePNG, {}
    )
    png_data.writeToFile_atomically_(path, True)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    generated, skipped, missing_src = [], [], []

    for stem, src_stem in SLOTS:
        out_path = os.path.join(OUT_DIR, f"{stem}.png")
        if os.path.exists(out_path):
            skipped.append(stem)
            continue

        src_path = os.path.join(RC_DIR, f"{src_stem}.png")
        if not os.path.exists(src_path):
            missing_src.append((stem, src_stem))
            continue

        img = make_watermark(src_path)
        save_png(img, out_path)
        generated.append(stem)
        print(f"  ✓  {stem}.png")

    print(f"\nGenerated: {len(generated)}  |  Skipped (exist): {len(skipped)}")
    if missing_src:
        print("  Missing source files:")
        for o, s in missing_src:
            print(f"    {o} ← {s}.png")


if __name__ == "__main__":
    main()
