# OG/Twitter Images - Quick Reference Card

## Images Created

### 1. og-image.jpg (49 KB)
- **Location:** `/public/og-image.jpg`
- **Size:** 1200x630 pixels
- **Use:** Facebook, LinkedIn, general web previews
- **Design:** Navy to Cyan gradient
- **Meta tag:** `<meta property="og:image" content="https://justlay.me/og-image.jpg" />`

### 2. twitter-image.jpg (41 KB)
- **Location:** `/public/twitter-image.jpg`
- **Size:** 1200x630 pixels
- **Use:** Twitter/X card sharing
- **Design:** Navy to Purple gradient
- **Meta tag:** `<meta name="twitter:image" content="https://justlay.me/twitter-image.jpg" />`

## Quick Deployment

1. Upload both JPG files to `/public/` on your web server
2. Verify `index.html` has the updated meta tags (already done)
3. Test with validators below

## Testing (Copy & Paste URLs)

1. **Facebook:** https://developers.facebook.com/tools/debug/
2. **Twitter:** https://cards-dev.twitter.com/validator
3. **LinkedIn:** https://www.linkedin.com/post-inspector/inspect/

## Regenerate Images

```bash
python3 /home/fastl/JustLayMe-react/generate-og-images.py
```

## Brand Colors

- Primary: #0f0f23 (Dark Navy)
- Accent 1: #8b5cf6 (Purple)
- Accent 2: #06b6d4 (Cyan)

## Files Reference

- **Images:** `/home/fastl/JustLayMe-react/public/og-image.jpg` + `twitter-image.jpg`
- **Generator:** `/home/fastl/JustLayMe-react/generate-og-images.py`
- **Full Spec:** `/home/fastl/JustLayMe-react/OG_IMAGE_SPECIFICATION.md`
- **Full Guide:** `/home/fastl/JustLayMe-react/SOCIAL_MEDIA_IMAGES_README.md`

---
Created: November 16, 2025
Status: Production Ready
