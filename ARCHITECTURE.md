# BubbleX - Vision Pro AR Application Architecture

## Overview
BubbleX is a visionOS application that displays X (Twitter) feeds as floating, interactive 3D bubbles in augmented reality using SwiftUI and RealityKit.

## Technical Stack
- **Platform**: visionOS 2.0+ (with conditional visionOS 3.0 features)
- **UI Framework**: SwiftUI with @main App lifecycle
- **3D Framework**: RealityKit with Entity-Component-System (ECS)
- **Networking**: async/await URLSession
- **Security**: Keychain for X API bearer token storage
- **Haptics**: Core Haptics for gesture feedback
- **Multiplayer**: SharePlay-ready (Group Activities framework)

## Project Structure

```
BubbleX5/
├── BubbleXApp.swift                    # Main app entry point with @main
├── BubbleX5.entitlements              # Required capabilities
├── Info.plist                          # Privacy descriptions
│
├── Views/
│   ├── ContentView.swift               # Main UI and AR toggle
│   └── DebugPanelView.swift           # Debug controls panel
│
├── Entities/
│   └── BubbleEntity.swift             # 3D bubble entity with tweet data
│
├── Components/                         # ECS Components
│   ├── BuoyancyComponent.swift        # Floating animation data
│   ├── OrbitComponent.swift           # Orbital movement data
│   └── DraggableComponent.swift       # Drag interaction state
│
├── Systems/                            # ECS Systems (update loops)
│   ├── BuoyancySystem.swift           # Handles floating motion
│   ├── OrbitSystem.swift              # Handles orbital movement
│   └── GestureSystem.swift            # Processes gestures + haptics
│
├── Services/
│   └── XAPIClient.swift               # X API integration with Keychain
│
├── Gestures/
│   └── HandGestureRecognizer.swift    # Hand tracking and gesture detection
│
├── Materials/
│   └── IridescentMaterial.swift       # Bubble visual materials
│
├── GroupActivities/
│   └── BubbleXActivity.swift          # SharePlay multiplayer support
│
├── Configuration/
│   └── VisionOSConfiguration.swift    # Version detection and feature flags
│
└── Assets.xcassets/                    # App icons and resources
```

## Core Features

### 1. Entity-Component-System Architecture
- **BubbleEntity**: Main 3D bubble objects containing tweet data
- **Components**: Pure data structures (Buoyancy, Orbit, Draggable)
- **Systems**: Logic processors that update entities each frame

### 2. Hand Tracking & Gestures
- ARKit hand tracking integration
- Pinch, grab, and point gesture recognition
- Haptic feedback on interactions

### 3. X API Integration
- Secure bearer token storage in Keychain
- async/await network calls
- Timeline fetching with proper error handling

### 4. SharePlay Support
- Group Activities framework integration
- Synchronized bubble updates across users
- Ready for multiplayer experiences

### 5. Conditional visionOS 3.0 Features
- Feature flags for version-specific capabilities
- Enhanced hand tracking on visionOS 3.0+
- Backward compatible with visionOS 2.0

## Required Entitlements

```xml
- com.apple.developer.arkit.hand-tracking
- com.apple.developer.arkit.world-sensing
- com.apple.developer.arkit.scene-understanding
- com.apple.developer.group-session
- com.apple.security.network.client
```

## Privacy Descriptions

The app requires user permission for:
- **Camera**: Passthrough AR experiences
- **Hand Tracking**: Natural gesture interactions
- **World Sensing**: AR content placement

## Key Design Patterns

1. **SwiftUI Lifecycle**: Modern @main app structure
2. **ImmersiveSpace**: Full-space AR rendering
3. **RealityView**: Main 3D content container
4. **Actor Isolation**: XAPIClient uses actor for thread safety
5. **Async/Await**: All network operations
6. **Keychain**: Secure credential storage
7. **ECS Pattern**: Clean separation of data and logic

## Build Configuration

- **Minimum visionOS**: 2.0
- **Target visionOS**: 3.0
- **Swift Version**: 5.9+
- **Xcode**: 15.0+

## Next Steps for Implementation

1. Configure X API bearer token via Debug Panel
2. Implement bubble tap interactions
3. Add spatial audio for bubble interactions
4. Complete SharePlay synchronization logic
5. Add gesture-based bubble creation
6. Implement tweet content rendering on bubbles

## Notes

- File system synchronized Xcode project automatically includes new files
- All systems are registered on app launch
- Haptic engine initialized in GestureSystem
- SharePlay sessions monitored continuously
- Logger subsystems for debugging: app, ar, network, gesture
