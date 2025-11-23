# App Store Screenshots Guide for JustLayMe

## Required Screenshot Sizes

### iPhone Screenshots (Required)

| Device | Size (px) | Aspect Ratio | Required |
|--------|-----------|--------------|----------|
| iPhone 15 Pro Max (6.7") | 1290 × 2796 | 9:19.5 | ✅ Required |
| iPhone 15 Pro (6.1") | 1179 × 2556 | 9:19.5 | Optional |
| iPhone 14 Plus (6.7") | 1284 × 2778 | 9:19.5 | ✅ Required |
| iPhone SE (4.7") | 750 × 1334 | 9:16 | Optional |
| iPhone 8 Plus (5.5") | 1242 × 2208 | 9:16 | ✅ Required |

### iPad Screenshots (If Supporting iPad)

| Device | Size (px) | Required |
|--------|-----------|----------|
| iPad Pro 12.9" (6th gen) | 2048 × 2732 | ✅ Required |
| iPad Pro 11" | 1668 × 2388 | Optional |

---

## Screenshot Requirements

### Apple Guidelines

- **Quantity**: 2-10 screenshots per device size
- **Format**: PNG or JPEG (no alpha)
- **Color Space**: sRGB or P3
- **No Bezels**: Don't include device frames (App Store adds them)
- **Accurate Content**: Screenshots must reflect actual app functionality
- **No Badges/Awards**: Don't include "App of the Day" etc.

---

## Recommended Screenshot Sequence

### Screenshot 1: Hero/Welcome
**Purpose**: First impression, show core value proposition

```
┌─────────────────────────┐
│                         │
│      JustLayMe          │
│                         │
│   Chat with AI that     │
│   understands you       │
│                         │
│   [Chat interface       │
│    preview]             │
│                         │
│   "Your AI companion"   │
│                         │
└─────────────────────────┘
```
**Caption**: "Chat with AI personalities that understand you"

---

### Screenshot 2: Chat Interface
**Purpose**: Show the main chat experience

```
┌─────────────────────────┐
│  ← Layme V1         ⋯   │
├─────────────────────────┤
│                         │
│        Hey! How can     │
│        I help you       │
│        today? 😊        │
│                         │
│   Tell me about         │
│   yourself              │
│                         │
│        I'm Layme, your  │
│        AI companion...  │
│                         │
│ ┌─────────────────┐ ➤  │
│ │ Type a message  │     │
│ └─────────────────┘     │
└─────────────────────────┘
```
**Caption**: "Engaging conversations with multiple AI personalities"

---

### Screenshot 3: Character Selection
**Purpose**: Show variety of AI characters

```
┌─────────────────────────┐
│  Characters         +   │
├─────────────────────────┤
│                         │
│  ┌────┐ ┌────┐ ┌────┐  │
│  │ 🤖 │ │ 🎭 │ │ ⚡ │  │
│  │V1  │ │Role│ │Fast│  │
│  │FREE│ │play│ │    │  │
│  └────┘ └────┘ └────┘  │
│                         │
│  Layme V1               │
│  FREE & Unlimited       │
│  ────────────────────   │
│  Your friendly AI...    │
│                         │
│  LayMe Uncensored       │
│  PREMIUM                │
│  ────────────────────   │
│  Unrestricted...        │
│                         │
└─────────────────────────┘
```
**Caption**: "Choose from multiple AI personalities"

---

### Screenshot 4: Character Creator (Premium Feature)
**Purpose**: Show customization capabilities

```
┌─────────────────────────┐
│  Create Character       │
├─────────────────────────┤
│                         │
│  Name: [My Custom AI  ] │
│                         │
│  Personality            │
│  ──────────────────     │
│  Friendliness  ●────○   │
│  Creativity    ●●───○   │
│  Humor         ●●●──○   │
│                         │
│  Speech Patterns        │
│  ┌────┐ ┌────┐ ┌────┐  │
│  │Warm│ │Wit │ │Fun │  │
│  └────┘ └────┘ └────┘  │
│                         │
│  [    Create    ]       │
│                         │
└─────────────────────────┘
```
**Caption**: "Create your own custom AI character"

---

### Screenshot 5: Premium Features
**Purpose**: Highlight subscription benefits

```
┌─────────────────────────┐
│  Upgrade to Premium 👑  │
├─────────────────────────┤
│                         │
│  Unlock Everything      │
│                         │
│  ✓ Unlimited AI models  │
│  ✓ Full chat history    │
│  ✓ Character creation   │
│  ✓ Priority support     │
│                         │
│  ┌─────────────────┐    │
│  │ Monthly  $9.99  │    │
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │ Yearly   $79.99 │ ⭐ │
│  │ Save 33%        │    │
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │ Lifetime  $199  │    │
│  └─────────────────┘    │
│                         │
└─────────────────────────┘
```
**Caption**: "Premium features for power users"

---

### Screenshot 6: Dark Mode Interface
**Purpose**: Show beautiful dark UI

```
┌─────────────────────────┐
│         Profile         │
├─────────────────────────┤
│                         │
│       ┌─────┐           │
│       │ JD  │           │
│       └─────┘           │
│     John Doe            │
│   john@email.com        │
│                         │
│  ┌─────────────────┐    │
│  │ 💬 1,234        │    │
│  │ Messages        │    │
│  └─────────────────┘    │
│                         │
│  ⚙️ Settings            │
│  📊 Statistics          │
│  🔒 Privacy             │
│                         │
└─────────────────────────┘
```
**Caption**: "Beautiful dark mode interface"

---

## Screenshot Creation Tools

### Recommended Tools

1. **Figma** (Free)
   - Templates available for App Store screenshots
   - Easy export at exact dimensions

2. **Sketch** (Mac)
   - Device frames built-in
   - Export presets for all sizes

3. **Rotato** (Mac)
   - 3D device mockups
   - Animated previews

4. **Screenshots Pro** (Mac App Store)
   - Drag & drop screenshot creation
   - All device sizes

### Quick Method: Simulator Screenshots

```bash
# 1. Run app in specific simulator
xcrun simctl boot "iPhone 15 Pro Max"

# 2. Take screenshot
xcrun simctl io booted screenshot screenshot.png

# 3. Screenshots are saved at exact device resolution
```

---

## App Preview Video (Optional)

### Specifications

| Device | Resolution | Duration |
|--------|------------|----------|
| iPhone 6.7" | 1290 × 2796 | 15-30 sec |
| iPhone 6.5" | 1284 × 2778 | 15-30 sec |
| iPhone 5.5" | 1080 × 1920 | 15-30 sec |
| iPad 12.9" | 2048 × 2732 | 15-30 sec |

### Guidelines
- MP4 or MOV format
- H.264 codec
- 30 fps
- No audio required (but can include)
- Show app in action
- First frame is poster image

---

## Localization

If supporting multiple languages, create screenshots for:

| Language | Priority |
|----------|----------|
| English (US) | Required |
| English (UK) | High |
| Spanish | High |
| French | High |
| German | Medium |
| Japanese | Medium |
| Chinese (Simplified) | Medium |
| Portuguese (Brazil) | Medium |

---

## Screenshot Checklist

### Before Creating
- [ ] App running with final UI
- [ ] Test account with sample data
- [ ] All features accessible
- [ ] Dark mode enabled

### During Creation
- [ ] Status bar shows: full signal, WiFi, 100% battery, 9:41 AM
- [ ] No personal information visible
- [ ] All text is spelled correctly
- [ ] UI matches current app version

### After Creating
- [ ] All required sizes created
- [ ] PNG format, no alpha
- [ ] Consistent style across all screenshots
- [ ] Captions written for each
- [ ] Uploaded to App Store Connect

---

## Final Screenshot List

| # | Content | Caption |
|---|---------|---------|
| 1 | Hero/Welcome | Chat with AI that understands you |
| 2 | Chat Interface | Engaging conversations with AI |
| 3 | Character Selection | Multiple AI personalities |
| 4 | Character Creator | Create custom characters |
| 5 | Premium Features | Unlock premium features |
| 6 | Profile/Dark Mode | Beautiful dark interface |
