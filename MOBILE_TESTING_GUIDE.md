# Mobile Payment Testing Guide

## Quick Testing Checklist

### Before Testing
- [ ] Ensure Stripe is configured (check `.env` for keys)
- [ ] Backend server is running
- [ ] Frontend dev server is running
- [ ] User is logged in

---

## Desktop Testing (5 min)

### Chrome DevTools
1. Open Chrome DevTools (F12)
2. Click "Toggle Device Toolbar" (Ctrl+Shift+M)
3. Select device: iPhone 12 Pro
4. Navigate to premium paywall
5. Test:
   - [ ] Modal opens correctly
   - [ ] Trust badges visible
   - [ ] All 3 pricing cards display
   - [ ] Buttons are large and easy to click
   - [ ] Click "Get Best Value" → Shows "Redirecting..."
   - [ ] Redirects to Stripe checkout

### Firefox Responsive Mode
1. Open Responsive Design Mode (Ctrl+Shift+M)
2. Select iPhone X/XS
3. Repeat tests above

---

## Real Device Testing (CRITICAL)

### iPhone (iOS Safari)
**Minimum Test:**
1. Open Safari on iPhone
2. Navigate to your JustLayMe site
3. Log in as a test user
4. Trigger premium paywall
5. Verify:
   - [ ] Modal fills screen nicely (not too small)
   - [ ] Text is readable (not too tiny)
   - [ ] Buttons are easy to tap (56-58px)
   - [ ] No accidental taps on wrong elements
   - [ ] Scrolling is smooth
   - [ ] Trust badges look good
   - [ ] Tap "Get Best Value"
   - [ ] Button gives visual feedback (scales down)
   - [ ] Shows "Redirecting..."
   - [ ] Redirects to Stripe
   - [ ] Stripe page is mobile-optimized
   - [ ] Can complete test payment
   - [ ] Redirects back to success page

**Test Multiple Screen Sizes:**
- iPhone SE (small)
- iPhone 12/13 (medium)
- iPhone 14 Pro Max (large)

### Android (Chrome)
**Same tests as iPhone:**
1. Open Chrome on Android
2. Navigate to site
3. Test paywall flow
4. Verify:
   - [ ] Layout looks good
   - [ ] Buttons are tap-friendly
   - [ ] Redirect works
   - [ ] Google Pay option appears on Stripe
   - [ ] Can return successfully

### Tablet Testing
**iPad / Android Tablet:**
1. Test in portrait mode
2. Test in landscape mode
3. Verify:
   - [ ] Cards display nicely (1-2 columns)
   - [ ] Touch targets are adequate
   - [ ] No weird spacing issues

---

## Specific Scenarios to Test

### 1. Not Logged In
- Trigger paywall
- Expected: Error message "Please log in to upgrade to premium"

### 2. Network Error
- Disable network mid-flow
- Expected: Error message shown, can retry

### 3. Stripe Cancellation
- Click plan → Redirect to Stripe
- Click "Back" or cancel on Stripe
- Expected: Returns to `/chat?cancelled=true`

### 4. Successful Payment
- Complete payment on Stripe
- Expected: Returns to `/chat?premium=success`
- Premium features should unlock

### 5. Small Screen (iPhone SE)
- Test on smallest iPhone
- Verify text doesn't overflow
- Buttons still tappable
- Can scroll to see all content

### 6. Landscape Mode
- Rotate phone to landscape
- Verify modal fits in viewport
- Can scroll if needed
- Buttons still accessible

---

## Visual Regression Checks

Compare before/after screenshots:

### Desktop (1920x1080)
- [ ] Modal centering
- [ ] 3-column grid
- [ ] Trust badges layout
- [ ] Button styling
- [ ] Color scheme

### Mobile (375x667 - iPhone SE)
- [ ] Single column layout
- [ ] Large buttons (56px+)
- [ ] Trust badges stacked
- [ ] Readable text
- [ ] Proper spacing

### Tablet (768x1024 - iPad)
- [ ] 1-2 column layout
- [ ] Touch-friendly elements
- [ ] Good use of space

---

## Performance Testing

### Mobile Load Time
- [ ] Modal opens in < 500ms
- [ ] No lag when scrolling
- [ ] Button tap responds immediately
- [ ] Redirect happens quickly

### Network Conditions
Test on:
- [ ] 4G (good connection)
- [ ] 3G (slower)
- [ ] Slow 3G (worst case)

All should work, just slower redirect.

---

## Browser Compatibility

### Mobile Browsers
- [ ] iOS Safari (latest)
- [ ] iOS Safari (iOS 14+)
- [ ] Android Chrome (latest)
- [ ] Android Firefox
- [ ] Samsung Internet

### Desktop Browsers
- [ ] Chrome
- [ ] Firefox
- [ ] Safari
- [ ] Edge

---

## Accessibility Testing

### Screen Reader
- [ ] Modal announces properly
- [ ] Buttons have aria-labels
- [ ] Price information is readable

### Keyboard Navigation
- [ ] Tab through elements
- [ ] Enter to activate buttons
- [ ] Escape to close modal

### Color Contrast
- [ ] Text is readable (WCAG AA)
- [ ] Buttons have good contrast
- [ ] Error messages are visible

---

## Common Issues & Fixes

### Issue: Buttons too small on mobile
**Fix:** Check SCSS - buttons should be min-height: 56px on mobile

### Issue: Modal doesn't fit on screen
**Fix:** Check max-height: 95vh and overflow-y: auto

### Issue: Trust badges overlap
**Fix:** Verify flex-wrap: wrap on .trust-indicators

### Issue: Redirect fails
**Fix:** Check browser console for errors, verify Stripe API keys

### Issue: Can't scroll on mobile
**Fix:** Ensure -webkit-overflow-scrolling: touch is set

### Issue: Text too small to read
**Fix:** Media query font sizes should be 0.9rem+ on mobile

---

## Testing Tools

### Chrome DevTools Device Mode
- Fast, built-in
- Good for quick checks
- Not 100% accurate for touch interactions

### BrowserStack / Sauce Labs
- Real device testing
- Paid service
- Most accurate

### Local Device Testing
- Best option if you have devices
- Test on your own iPhone/Android
- Most realistic

---

## Sign-Off Criteria

Before deploying to production:

- [ ] Tested on at least 2 real mobile devices (iOS + Android)
- [ ] Tested on tablet
- [ ] Tested on desktop
- [ ] All payment flows work (monthly, yearly, lifetime)
- [ ] Error handling works
- [ ] Success/cancel redirects work
- [ ] No console errors
- [ ] Buttons are easily tappable
- [ ] Text is readable on all screen sizes
- [ ] Performance is acceptable (< 1s load)
- [ ] Trust badges display correctly
- [ ] Modal is visually appealing

---

## Quick Command Reference

### Start Dev Environment
```bash
# Terminal 1 - Backend
cd /home/fastl/JustLayMe
npm start

# Terminal 2 - Frontend
cd /home/fastl/JustLayMe/client
npm run dev
```

### Clear Browser Cache
- Chrome: Ctrl+Shift+Delete
- Safari iOS: Settings → Safari → Clear History

### Inspect on Real Device
- iOS: Safari → Develop → [Device] → [Page]
- Android: Chrome → chrome://inspect

---

## Success Metrics Post-Deploy

Monitor for 1-2 weeks:

### Key Metrics
- Mobile conversion rate (% who complete payment)
- Desktop conversion rate
- Mobile vs Desktop comparison
- Drop-off rate (% who click plan but don't complete)
- Average session time
- Error rate

### Target Improvements
- **Mobile Conversion:** +30-50% improvement
- **Drop-off:** -20-30% reduction
- **Errors:** < 1% of attempts

---

## Rollback Trigger

Rollback to old embedded checkout if:
- Mobile conversion rate DROPS by > 10%
- Error rate exceeds 5%
- Critical bugs reported by > 10 users
- Payment failures increase

Follow rollback plan in MOBILE_PAYMENT_OPTIMIZATION.md

---

## Contact for Issues

If you encounter blocking issues:
1. Check browser console for errors
2. Verify Stripe configuration
3. Test with Stripe test cards
4. Review backend logs
5. Check network tab for API failures

**Stripe Test Cards:**
- Success: 4242 4242 4242 4242
- Decline: 4000 0000 0000 0002
- 3D Secure: 4000 0025 0000 3155
