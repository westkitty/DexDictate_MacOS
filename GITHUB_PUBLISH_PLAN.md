# GitHub Publish Plan

## Summary
- Git repository detected locally (`.git` exists). No git commands will run until approval.
- PII scan: **no matches** for emails or phone numbers.
- Secret scan: **no matches** for credentials or tokens.

## Files to Commit
- .gitignore
- README.md
- Package.swift
- build.sh
- reset_tcc_permissions.sh
- dexdictatebanner.webp
- Sources/DexDictate/DexDictate.entitlements
- Sources/DexDictate/DexDictateApp.swift
- Sources/DexDictate/InputMonitor.swift
- Sources/DexDictate/Safety.swift
- Sources/DexDictate/Settings.swift
- Sources/DexDictate/SettingsView.swift
- Sources/DexDictate/TranscriptionEngine.swift
- Sources/DexDictate/Resources/Assets.xcassets/AppIcon.appiconset/icon.png
- Sources/DexDictate/Resources/Assets.xcassets/dexdictatebanner.webp
- Sources/DexDictate/Resources/Assets.xcassets/dog_background.imageset/Contents.json
- Sources/DexDictate/Resources/Assets.xcassets/dog_background.imageset/dog_background.png
- Sources/DexDictate/Resources/Assets.xcassets/dog_background.imageset/DexDictateMacOS_Icon.png

## Files Ignored
- .build/
- DerivedData/
- *.app
- *.xcodeproj
- *.xcworkspace
- xcuserdata/
- .swiftpm/
- .idea/
- .vscode/
- .DS_Store
- Thumbs.db
- node_modules/
- venv/ and .venv/
- dist/ build/ target/ coverage/
- .env and .env.*
- secrets.json and *.key/*.pem/*.p12/*.cer

## Remote Target
- https://github.com/WestKitty/DexDictate_MacOS.git

## Proposed Commit Message
- feat: prepare repository for public release
