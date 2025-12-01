# BubbleX - Quick Start Guide

## ⚡ Getting Started (5 minutes)

### 1. Open the Project
```bash
open BubbleX5.xcodeproj
```

### 2. Select Target
- Product → Destination → Vision Pro (simulator or device)

### 3. Build & Run
- Press ⌘R or click the Play button
- Wait for build to complete (~30 seconds first time)

### 4. Grant Permissions
When prompted, allow:
- Camera access (for AR passthrough)
- Hand tracking (for gestures)
- World sensing (for spatial mapping)

### 5. Enter AR Mode
- Tap the blue "Enter AR" button
- You'll see 5 floating bubbles appear
- Bubbles will animate with buoyancy effect

---

## 🎮 Controls

### Main Window
- **Enter AR** - Opens immersive AR space
- **Exit AR** - Closes immersive space
- **Debug** - Opens debug panel (only visible in AR mode)

### Debug Panel
- Bubble Count slider (1-20)
- Toggle buoyancy effect on/off
- Toggle orbit mode on/off
- Toggle haptic feedback
- View hand tracking status
- Configure X API bearer token
- Reset scene

---

## 🔧 Customization

### Edit Bubble Behavior
Open `BubbleX5/Utilities/Constants.swift`:

```swift
struct Bubble {
    static let minRadius: Float = 0.05      // Smaller bubbles
    static let maxRadius: Float = 0.2       // Larger bubbles
}
```

### Change Spawn Location
```swift
struct Scene {
    static let spawnZoneMin = SIMD3<Float>(-1.0, -0.5, -1.5)
    static let spawnZoneMax = SIMD3<Float>(1.0, 0.5, -0.5)
}
```

### Adjust Float Animation
```swift
struct Bubble {
    static let minBuoyancyAmplitude: Float = 0.03  // Subtle
    static let maxBuoyancyAmplitude: Float = 0.2   // Dramatic
}
```

---

## 🐛 Troubleshooting

### Build Errors
**Error**: "No such module 'RealityKit'"
- Solution: Ensure target is set to visionOS (not iOS)

**Error**: Missing entitlements
- Solution: Check BubbleX5.entitlements is included in target

### Runtime Issues
**Issue**: Bubbles don't appear
- Check: Are you in AR mode (tapped "Enter AR")?
- Check: Console for any errors (⌘Y to show)

**Issue**: Hand tracking not working
- Check: Permission granted in Settings?
- Check: Vision Pro hand tracking is enabled
- Check: Hands are visible to cameras

**Issue**: App crashes on launch
- Check: Running on visionOS 2.0+ simulator/device
- Check: Xcode 15.0 or later installed

---

## 📱 X API Setup

### 1. Get Bearer Token
- Go to https://developer.twitter.com/
- Create an app and generate bearer token
- Copy the token (starts with "AAAA...")

### 2. Add to BubbleX
- Launch app in AR mode
- Tap "Debug" button
- Tap "Configure Bearer Token"
- Paste your token
- Tap "Save"

### 3. Fetch Tweets
- In Debug Panel, tap "Fetch Timeline"
- Bubbles will update with real tweet data

---

## 🎨 Visual Customization

### Change Bubble Colors
Edit `BubbleX5/Entities/BubbleEntity.swift:33`:

```swift
material.baseColor = .init(
    tint: .init(
        hue: 0.5,           // 0.0=red, 0.3=green, 0.6=blue
        saturation: 0.7,
        brightness: 0.9
    )
)
```

### Adjust Transparency
Edit `BubbleX5/Utilities/Constants.swift`:

```swift
static let defaultOpacity: Float = 0.65  // 0.0=invisible, 1.0=solid
```

### Add New Materials
Check `BubbleX5/Materials/IridescentMaterial.swift` for examples:
- `create(baseHue:)` - Single color
- `createShimmering(phase:)` - Animated color
- `rainbow()` - Multi-color array

---

## 📚 Code Structure

### Add New Component
1. Create file in `Components/`
2. Make it conform to `Component, Codable, Sendable`
3. Add it to entities in `BubbleEntity.create()`

### Add New System
1. Create file in `Systems/`
2. Conform to `System` protocol
3. Define `EntityQuery`
4. Implement `update(context:)`
5. Register in `ContentView.initializeBubbleSystem()`

### Add New View
1. Create file in `Views/`
2. Import SwiftUI
3. Create `struct YourView: View`
4. Present from `ContentView` or `DebugPanelView`

---

## 🚀 Performance Tips

- Keep bubble count ≤ 20 for smooth 60 FPS
- Buoyancy calculations are already optimized
- Avoid complex shaders in materials
- Use `.maybeSingle()` for single queries

---

## 📖 Next Steps

1. **Read**: `ARCHITECTURE.md` for technical details
2. **Review**: `PROJECT_SUMMARY.md` for complete feature list
3. **Explore**: Each Swift file has inline documentation
4. **Build**: Add your own components and systems!

---

## 💡 Pro Tips

- Use Debug Panel to experiment with settings
- Check Xcode console for Logger output
- Systems update every frame (inspect in Reality Composer Pro)
- Hand gestures work best 0.3-0.8m from face
- SharePlay code is ready but needs activation logic

---

## 🆘 Need Help?

- Check console logs (⌘Y in Xcode)
- Review `Logger.app`, `Logger.ar`, etc. output
- Verify entitlements in project settings
- Ensure Info.plist has all privacy descriptions

---

**Ready to build!** Press ⌘R and start exploring AR! 🚀
