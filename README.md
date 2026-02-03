# Banshee

Banshee is an iOS MVP for playing the classic 1977 board wargame **Ogre** in hot-seat mode. The MVP focuses on the original turn sequence, combat results table, and basic unit stats, delivered with a SwiftUI + SpriteKit interface.

## Status
- SwiftUI + SpriteKit app scaffolded
- Hex map rendering + unit selection/movement
- Turn phases and combat resolution
- Record sheet + rules summary screens

## Build
1. Open `Banshee/Banshee.xcodeproj` in Xcode 15+.
2. Set your signing team in the project settings.
3. Build and run on an iOS 16+ simulator/device.

## Notes
- Map terrain (craters/ridges) is currently empty in `Banshee/Banshee/Game/MapData.swift` and can be populated to match the classic Ogre map.
