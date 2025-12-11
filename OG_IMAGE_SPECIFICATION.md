# OG Image and Twitter Card Specification

## Overview
This document specifies the Open Graph (OG) and Twitter Card images for JustLayMe. These images are critical for social media sharing and preview generation.

## Current Implementation Status

### Files Created
- `/public/og-image.jpg` - Open Graph image (49KB)
- `/public/twitter-image.jpg` - Twitter Card image (41KB)
- `/public/og-image.svg` - Source SVG (existing)

### Image Specifications

#### Dimensions
- **Width:** 1200 pixels
- **Height:** 630 pixels
- **Aspect Ratio:** 1.905:1 (standard for OG and Twitter)
- **Format:** JPEG (90% quality)
- **File Size:** ~45-50KB (optimized)

#### Brand Colors Used
- **Dark Background:** #0f0f23 (Dark navy)
- **Purple Accent:** #8b5cf6 (Vibrant purple)
- **Cyan Accent:** #06b6d4 (Bright cyan)
- **Text Primary:** #ffffff (White)
- **Text Secondary:** #e5e7eb (Light gray)

#### Design Elements

##### OG Image (og-image.jpg)
- **Background:** Gradient from dark (#0f0f23) to cyan (#06b6d4)
- **Main Title:** "JustLayMe" (90px bold)
- **Subtitle:** "Unfiltered AI Conversations" (48px cyan)
- **Tagline:** "Chat Without Restrictions" (36px light gray)
- **Decorative Elements:** Circular border accent in bottom-right
- **Typography:** DejaVuSans family

##### Twitter Card Image (twitter-image.jpg)
- **Background:** Gradient from dark (#0f0f23) to purple (#8b5cf6)
- **Main Title:** "JustLayMe" (85px bold)
- **Subtitle:** "Unfiltered AI Conversations" (42px purple)
- **Tagline:** "Chat Without Restrictions" (32px white)
- **Decorative Elements:** Square border accent in top-left
- **Typography:** DejaVuSans family

## Implementation Details

### Image Generation Script
Located at: `/home/fastl/JustLayMe-react/generate-og-images.py`

The script uses Python PIL (Pillow) to generate images programmatically with:
- Gradient backgrounds with diagonal color transitions
- Text rendering with proper centering
- Decorative geometric elements
- JPEG compression at 90% quality for optimal file size

#### Running the Script
```bash
cd /home/fastl/JustLayMe-react
python3 generate-og-images.py
```

### HTML Implementation

Add the following meta tags to your HTML head section (index.html):

```html
<!-- Open Graph Meta Tags -->
<meta property="og:type" content="website" />
<meta property="og:url" content="https://justlaycom/" />
<meta property="og:title" content="JustLayMe - Unfiltered AI Conversations" />
<meta property="og:description" content="Chat without restrictions. Experience pure, unfiltered AI conversations." />
<meta property="og:image" content="https://justlay.me/og-image.jpg" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:image:type" content="image/jpeg" />

<!-- Twitter Card Meta Tags -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="JustLayMe - Unfiltered AI Conversations" />
<meta name="twitter:description" content="Chat without restrictions. Experience pure, unfiltered AI conversations." />
<meta name="twitter:image" content="https://justlay.me/twitter-image.jpg" />
<meta name="twitter:creator" content="@justlayai" />
<meta name="twitter:url" content="https://justlay.me/" />
```

## Design Best Practices

### Why These Specific Design Choices

1. **Large Clear Typography**
   - 90px+ titles ensure readability at small preview sizes (thumbnail previews)
   - Bold font weight increases contrast and legibility

2. **Gradient Backgrounds**
   - Creates visual interest and depth
   - Supports brand colors and maintains visual identity
   - Complements modern SaaS design aesthetic

3. **Centered Text Layout**
   - Maximizes visual prominence
   - Professional appearance
   - Easy to read at any size

4. **Decorative Elements**
   - Adds sophistication without cluttering
   - Provides visual balance
   - Reinforces brand identity

5. **Separate Twitter/OG Variants**
   - OG uses cyan gradient for general web previews
   - Twitter uses purple gradient for platform consistency
   - Different layouts optimized for each platform's behavior

## Recommended Enhancements

### For Professional Design
If you want to further enhance these images, consider:

1. **Custom Logo Integration**
   - Add a stylized JustLayMe logo or icon
   - Position in corner or as decorative element
   - Ensure adequate whitespace around it

2. **Subtle Patterns or Textures**
   - Add noise or geometric patterns to background
   - Creates more visual interest
   - Keep pattern subtle to avoid distraction

3. **Additional Visual Hierarchy**
   - Consider adding a secondary icon or badge
   - Reinforces product positioning
   - Examples: "AI Powered", "No Filters", etc.

4. **Professional Photography or Illustration**
   - Replace gradient with subtle background image
   - Add illustrated elements (robots, chat bubbles, etc.)
   - Ensure readability of text over background

## Testing and Validation

### Test Your Meta Tags

1. **Facebook Sharing Debugger**
   - URL: https://developers.facebook.com/tools/debug/
   - Verify OG image displays correctly
   - Check all metadata is properly formatted

2. **Twitter Card Validator**
   - URL: https://cards-dev.twitter.com/validator
   - Ensure Twitter Card image displays
   - Validate card type and content

3. **LinkedIn Post Inspector**
   - URL: https://www.linkedin.com/post-inspector/inspect/
   - Verify image quality and sizing

4. **Manual Testing**
   - Share link on social media platforms
   - Verify preview appearance
   - Check image dimensions (should be 1200x630)

## File Specifications Summary

| Aspect | Specification |
|--------|---------------|
| Dimensions | 1200x630 pixels |
| Format | JPEG |
| Quality | 90% |
| File Size | ~40-50KB |
| Aspect Ratio | 1.905:1 |
| Color Mode | RGB (8-bit) |
| DPI | 72 (standard for web) |

## Source Files

- **SVG Source:** `/public/og-image.svg` (original vector)
- **Python Generator:** `/generate-og-images.py` (if regeneration needed)
- **OG Image:** `/public/og-image.jpg` (current)
- **Twitter Image:** `/public/twitter-image.jpg` (current)

## Regenerating Images

If you need to modify the images:

1. Edit `/generate-og-images.py` to change colors, text, or layout
2. Run: `python3 generate-og-images.py`
3. Images will be regenerated in `/public/`
4. Test with social media debuggers (see Testing and Validation section)

## Additional Resources

- [Open Graph Protocol](https://ogp.me/)
- [Twitter Cards Documentation](https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/abouts-cards)
- [Facebook Sharing Best Practices](https://developers.facebook.com/docs/sharing/webmasters)
- [LinkedIn Image Requirements](https://www.linkedin.com/help/linkedin/answer/a419335)

---

**Last Updated:** November 16, 2025
**Generated by:** Image Generation Script (Python PIL)
**Status:** Production Ready
