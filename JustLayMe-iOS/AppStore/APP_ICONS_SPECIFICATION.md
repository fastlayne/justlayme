# App Icon Specifications for JustLayMe

## Required Icon Sizes

### iOS App Icons (Required)

| Size (px) | Scale | Usage | Filename |
|-----------|-------|-------|----------|
| 1024×1024 | 1x | App Store | AppIcon-1024.png |
| 180×180 | 3x | iPhone App (@3x) | AppIcon-60@3x.png |
| 120×120 | 2x | iPhone App (@2x) | AppIcon-60@2x.png |
| 167×167 | 2x | iPad Pro App | AppIcon-83.5@2x.png |
| 152×152 | 2x | iPad App | AppIcon-76@2x.png |
| 76×76 | 1x | iPad App | AppIcon-76.png |

### Spotlight & Settings Icons

| Size (px) | Scale | Usage | Filename |
|-----------|-------|-------|----------|
| 120×120 | 3x | iPhone Spotlight (@3x) | AppIcon-40@3x.png |
| 80×80 | 2x | iPhone Spotlight (@2x) | AppIcon-40@2x.png |
| 80×80 | 2x | iPad Spotlight (@2x) | AppIcon-40@2x.png |
| 40×40 | 1x | iPad Spotlight | AppIcon-40.png |
| 87×87 | 3x | iPhone Settings (@3x) | AppIcon-29@3x.png |
| 58×58 | 2x | iPhone Settings (@2x) | AppIcon-29@2x.png |
| 58×58 | 2x | iPad Settings (@2x) | AppIcon-29@2x.png |
| 29×29 | 1x | iPad Settings | AppIcon-29.png |

### Notification Icons

| Size (px) | Scale | Usage | Filename |
|-----------|-------|-------|----------|
| 60×60 | 3x | iPhone Notification (@3x) | AppIcon-20@3x.png |
| 40×40 | 2x | iPhone Notification (@2x) | AppIcon-20@2x.png |
| 40×40 | 2x | iPad Notification (@2x) | AppIcon-20@2x.png |
| 20×20 | 1x | iPad Notification | AppIcon-20.png |

---

## Design Specifications

### Brand Colors
```
Primary Purple: #8B5CF6
Primary Light: #A78BFA
Dark Background: #0F0F23
```

### Icon Design Guidelines

1. **Shape**: iOS automatically applies rounded corners - design as square
2. **Safe Zone**: Keep important content within center 80%
3. **No Transparency**: iOS icons cannot have transparent backgrounds
4. **No Alpha Channel**: Remove alpha channel from final exports
5. **Color Profile**: sRGB
6. **Format**: PNG (no interlacing)

### Recommended Design

```
┌─────────────────────────┐
│                         │
│    ┌───────────────┐    │
│    │               │    │
│    │   💬  💬      │    │  ← Chat bubble icons
│    │               │    │
│    └───────────────┘    │
│                         │
│      JustLayMe          │  ← Optional: text below
│                         │
└─────────────────────────┘

Background: Gradient from #8B5CF6 to #A78BFA
Icon: White chat bubbles (SF Symbol: bubble.left.and.bubble.right.fill)
```

---

## Asset Catalog Configuration

### Contents.json for AppIcon.appiconset

```json
{
  "images": [
    {
      "filename": "AppIcon-1024.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    },
    {
      "filename": "AppIcon-16.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "16x16"
    },
    {
      "filename": "AppIcon-16@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "16x16"
    },
    {
      "filename": "AppIcon-32.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "32x32"
    },
    {
      "filename": "AppIcon-32@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "32x32"
    },
    {
      "filename": "AppIcon-128.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "128x128"
    },
    {
      "filename": "AppIcon-128@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "128x128"
    },
    {
      "filename": "AppIcon-256.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "256x256"
    },
    {
      "filename": "AppIcon-256@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "256x256"
    },
    {
      "filename": "AppIcon-512.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "512x512"
    },
    {
      "filename": "AppIcon-512@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "512x512"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

---

## Icon Generation Script

### Using ImageMagick

```bash
#!/bin/bash
# generate-icons.sh

SOURCE="AppIcon-1024.png"
OUTPUT_DIR="AppIcon.appiconset"

mkdir -p "$OUTPUT_DIR"

# iOS Icons
convert "$SOURCE" -resize 1024x1024 "$OUTPUT_DIR/AppIcon-1024.png"
convert "$SOURCE" -resize 180x180 "$OUTPUT_DIR/AppIcon-60@3x.png"
convert "$SOURCE" -resize 120x120 "$OUTPUT_DIR/AppIcon-60@2x.png"
convert "$SOURCE" -resize 167x167 "$OUTPUT_DIR/AppIcon-83.5@2x.png"
convert "$SOURCE" -resize 152x152 "$OUTPUT_DIR/AppIcon-76@2x.png"
convert "$SOURCE" -resize 76x76 "$OUTPUT_DIR/AppIcon-76.png"

# Spotlight
convert "$SOURCE" -resize 120x120 "$OUTPUT_DIR/AppIcon-40@3x.png"
convert "$SOURCE" -resize 80x80 "$OUTPUT_DIR/AppIcon-40@2x.png"
convert "$SOURCE" -resize 40x40 "$OUTPUT_DIR/AppIcon-40.png"

# Settings
convert "$SOURCE" -resize 87x87 "$OUTPUT_DIR/AppIcon-29@3x.png"
convert "$SOURCE" -resize 58x58 "$OUTPUT_DIR/AppIcon-29@2x.png"
convert "$SOURCE" -resize 29x29 "$OUTPUT_DIR/AppIcon-29.png"

# Notification
convert "$SOURCE" -resize 60x60 "$OUTPUT_DIR/AppIcon-20@3x.png"
convert "$SOURCE" -resize 40x40 "$OUTPUT_DIR/AppIcon-20@2x.png"
convert "$SOURCE" -resize 20x20 "$OUTPUT_DIR/AppIcon-20.png"

# Mac Icons
convert "$SOURCE" -resize 16x16 "$OUTPUT_DIR/AppIcon-16.png"
convert "$SOURCE" -resize 32x32 "$OUTPUT_DIR/AppIcon-16@2x.png"
convert "$SOURCE" -resize 32x32 "$OUTPUT_DIR/AppIcon-32.png"
convert "$SOURCE" -resize 64x64 "$OUTPUT_DIR/AppIcon-32@2x.png"
convert "$SOURCE" -resize 128x128 "$OUTPUT_DIR/AppIcon-128.png"
convert "$SOURCE" -resize 256x256 "$OUTPUT_DIR/AppIcon-128@2x.png"
convert "$SOURCE" -resize 256x256 "$OUTPUT_DIR/AppIcon-256.png"
convert "$SOURCE" -resize 512x512 "$OUTPUT_DIR/AppIcon-256@2x.png"
convert "$SOURCE" -resize 512x512 "$OUTPUT_DIR/AppIcon-512.png"
convert "$SOURCE" -resize 1024x1024 "$OUTPUT_DIR/AppIcon-512@2x.png"

echo "Icons generated successfully!"
```

---

## Online Icon Generators

If you don't have design tools, use these services:

1. **App Icon Generator** (Free)
   - https://www.appicon.co
   - Upload 1024×1024 PNG, download all sizes

2. **MakeAppIcon** (Free)
   - https://makeappicon.com
   - Generates all required sizes

3. **Icon Kitchen** (Free)
   - https://icon.kitchen
   - Material design icons, customizable

---

## Checklist

- [ ] 1024×1024 source icon designed
- [ ] No transparency in icon
- [ ] sRGB color profile
- [ ] All sizes exported
- [ ] Contents.json updated
- [ ] Icons added to Assets.xcassets/AppIcon.appiconset
- [ ] Build successful with new icons
- [ ] Icons display correctly on device
