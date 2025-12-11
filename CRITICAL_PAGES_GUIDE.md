# Critical Pages Implementation Guide

## Quick Reference

This document describes the two critical pages added to the JustLayMe app.

## 1. NotFoundPage (404)

**Route:** `*` (catch-all for any undefined route)
**Files:**
- `/src/pages/NotFoundPage.jsx` - Component
- `/src/pages/NotFoundPage.scss` - Styles

### What it does:
- Displays a friendly 404 error page
- Provides navigation back to home or chat
- Shows helpful quick links
- Fully responsive with dark theme

### Key Features:
- Animated 404 code display
- Particle background animations
- Two main CTAs: "Back to Home" and "Go to Chat"
- Help section with links to Features, Pricing, About
- SEO optimized with proper meta tags
- Accessible keyboard navigation
- Respects prefers-reduced-motion

### Usage:
When users navigate to any non-existent route (e.g., `/invalid-route`), they'll automatically see this page thanks to the catch-all route in App.jsx.

```javascript
// In App.jsx
<Route path="*" element={<NotFoundPage />} />
```

### Customization:
To modify the quick links in the help section, edit the help-links section in NotFoundPage.jsx.

---

## 2. PremiumPage (Pricing)

**Route:** `/premium`
**Files:**
- `/src/pages/PremiumPage.jsx` - Component
- `/src/pages/PremiumPage.scss` - Styles

### What it does:
- Displays comprehensive pricing tiers
- Shows detailed feature comparison
- Provides upgrade flow integration
- Educational FAQ section
- Responsive pricing cards with hover effects

### Pricing Tiers:
1. **Free** - $0/month
   - Limited conversations
   - Basic AI models
   - 1 character slot

2. **Premium** - $9.99/month (or $79.99/year)
   - Unlimited conversations
   - All AI models
   - Unlimited characters
   - Voice cloning
   - Black Mirror analysis

3. **Pro** - $19.99/month (or $199.99 lifetime)
   - Everything in Premium
   - API access
   - Custom models
   - Advanced analytics
   - Dedicated support

### Key Features:
- Feature comparison matrix (11 features tracked)
- Dynamic premium status awareness (shows current plan if premium)
- Integration with PremiumPaywallModal for purchases
- FAQ section with common questions
- Sticky navigation for easy access
- SEO optimized title and meta description
- Mobile-responsive grid layouts

### Usage:
Navigate to `/premium` to see the pricing page.

```javascript
// In navigation or links
<Link to="/premium">View Pricing</Link>
// Or programmatically:
navigate('/premium')
```

### Adding New Features to Comparison:
Edit the `features` array in PremiumPage.jsx:

```javascript
const features = [
  {
    name: 'Feature Name',
    free: 'Free tier value',
    premium: 'Premium tier value',
    pro: 'Pro tier value'
  },
  // Add more...
]
```

### Updating Prices:
Update the pricing cards in the JSX section. The component also fetches Stripe pricing when upgrade buttons are clicked via `PremiumPaywallModal`.

---

## Integration Points

### Authentication
Both pages are aware of user authentication state:
```javascript
const { user, isPremium } = useAuth()
```

**NotFoundPage:** Doesn't require auth, shows welcome state.
**PremiumPage:** Shows different CTAs based on login/premium status.

### Navigation
Both pages integrate with the page transition system:
```javascript
const { startTransition } = usePageTransition()
```

### Payment Flow
PremiumPage integrates with the existing payment system:
```javascript
// Clicking upgrade buttons opens PremiumPaywallModal
<PremiumPaywallModal
  modalId="premium-page-paywall"
  onClose={() => setShowPaywall(false)}
  feature={selectedFeature}
/>
```

---

## Styling & Theming

Both pages follow the JustLayMe design system:
- **Colors:** Dark theme with cyan (#06b6d4) accents
- **Font:** Uses Segoe UI / Inter with Orbitron for display
- **Spacing:** Consistent 8px-based spacing system
- **Animations:** Smooth CSS transitions and keyframe animations

Key SCSS imports:
```scss
@import '@/styles/variables.scss';
```

This provides access to:
- Color variables ($primary, $secondary, etc.)
- Spacing system ($spacing-xs through $spacing-3xl)
- Typography ($font-family-body, $font-size-xl, etc.)
- Shadows and effects ($shadow-glow, $shadow-neon, etc.)

---

## Accessibility Compliance

Both pages include:
- ✓ Semantic HTML (main, nav, section elements)
- ✓ ARIA labels for interactive elements
- ✓ Keyboard navigation (Tab through buttons)
- ✓ Focus states (outline indicators)
- ✓ Color contrast compliance
- ✓ Reduced motion support
- ✓ Screen reader friendly

---

## Performance Considerations

### Code Splitting
Both pages are lazy-loaded to reduce initial bundle size:
```javascript
const PremiumPage = lazy(() => import('./pages/PremiumPage'))
const NotFoundPage = lazy(() => import('./pages/NotFoundPage'))
```

### Loading States
Both routes have Suspense fallbacks:
```javascript
<Suspense fallback={<LoadingSpinner message="Loading Premium..." />}>
  <PremiumPage />
</Suspense>
```

### CSS Organization
- Shared variables reduce duplication
- Mobile-first responsive design
- Efficient animations using CSS keyframes

---

## Testing Guide

### Manual Testing

#### NotFoundPage:
1. Navigate to `http://localhost:5173/invalid-route`
2. Verify 404 page displays
3. Click "Back to Home" - should go to `/`
4. Click "Go to Chat" - should go to `/chat`
5. Test mobile view - layout should stack vertically
6. Test keyboard nav - Tab through buttons should work

#### PremiumPage:
1. Navigate to `http://localhost:5173/premium`
2. Verify all three pricing cards display
3. Click an upgrade button when logged in - should open modal
4. Scroll down and verify feature comparison table
5. Check FAQ section is readable
6. Test mobile view - cards should be single column
7. Verify premium badge shows if user is premium

### Automated Testing
Consider adding tests for:
- Route existence and correct component rendering
- Authentication state handling
- Button click handlers
- Modal opening/closing
- Responsive breakpoints

---

## Common Issues & Solutions

### Issue: 404 page appears when it shouldn't
**Solution:** Check that the catch-all route `<Route path="*" />` is the LAST route in the Routes component.

### Issue: Upgrade button doesn't open modal
**Solution:** Verify user is logged in. Check that PremiumPaywallModal component is imported correctly.

### Issue: Pricing table is hard to read on mobile
**Solution:** The table has horizontal scroll on small screens. Consider adding a mobile-friendly view if needed.

### Issue: Animations feel slow on mobile
**Solution:** Check user's prefers-reduced-motion setting. CSS respects this automatically.

---

## Future Enhancements

Potential improvements for these pages:

### NotFoundPage:
- Add search functionality
- Show recently visited pages
- Suggest popular pages based on behavior
- Add error tracking/reporting

### PremiumPage:
- Dynamic pricing based on location
- Annual/lifetime pricing toggle
- Testimonials section
- Comparison with competitors
- Interactive pricing calculator
- FAQ accordion for better UX
- Analytics tracking for conversions

---

## File Structure

```
src/
├── pages/
│   ├── NotFoundPage.jsx       (4.6 KB)
│   ├── NotFoundPage.scss      (8.6 KB)
│   ├── PremiumPage.jsx        (19 KB)
│   ├── PremiumPage.scss       (11 KB)
│   └── ... (other pages)
├── App.jsx                     (updated)
└── ... (other app files)
```

---

## Development Tips

### Adding Components to NotFoundPage:
The page uses these shared components:
- `Magnet` - Interactive button wrapper
- `LightRays` - Background effect
- No additional dependencies needed

### Adding Components to PremiumPage:
The page uses these shared components:
- `ShinyText` - Animated text effect
- `RevealContainer` - Scroll reveal animation
- `SpotlightCard` - Featured card component
- `LightRays` - Background effect
- `RotatingText` - Animated rotation
- `PremiumPaywallModal` - Payment integration

### Debugging:
Enable React DevTools to inspect:
- Component props
- State changes
- Context consumption
- Performance profiling

---

## Questions?

Refer to the main README or check similar pages (IndexPage, LoginPage) for patterns used throughout the app.
