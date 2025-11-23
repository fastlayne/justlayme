# Accessibility Implementation Checklist

**Project:** JustLayMe
**Start Date:** November 21, 2025
**Target Date:** [To be set]

---

## PHASE 1: CRITICAL ISSUES (Week 1)

### 1.1 Create Focus Trap Hook
- [ ] Create `/src/hooks/useFocusTrap.js`
- [ ] Implement focus trap logic
- [ ] Handle Tab/Shift+Tab
- [ ] Handle Escape key
- [ ] Move focus into modal on open
- [ ] Return focus after close
- [ ] Document usage
- [ ] Test focus trap behavior

**File:** `/home/fastl/JustLayMe/client/src/hooks/useFocusTrap.js`
**Effort:** 1-2 hours
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 1.2 Update SettingsModal with Focus Trap
- [ ] Import useFocusTrap hook
- [ ] Add modalRef to use hook
- [ ] Add role="dialog" to modal
- [ ] Add aria-modal="true"
- [ ] Add aria-labelledby to modal
- [ ] Add id to modal title
- [ ] Implement focus return on close
- [ ] Handle ESC key
- [ ] Test keyboard navigation
- [ ] Test screen reader announcement

**File:** `/home/fastl/JustLayMe/client/src/components/modals/SettingsModal.jsx`
**Effort:** 1 hour
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 1.3 Update NeuralCharacterBuilder with Focus Trap
- [ ] Import useFocusTrap hook
- [ ] Add focus trap logic
- [ ] Add role="dialog" attributes
- [ ] Update ARIA labels
- [ ] Test implementation

**File:** `/home/fastl/JustLayMe/client/src/components/modals/NeuralCharacterBuilder.jsx`
**Effort:** 45 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 1.4 Update PremiumPaywallModal with Focus Trap
- [ ] Import useFocusTrap hook
- [ ] Add focus trap logic
- [ ] Add role="dialog" attributes
- [ ] Update ARIA labels

**File:** `/home/fastl/JustLayMe/client/src/components/modals/PremiumPaywallModal.jsx`
**Effort:** 45 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 1.5 Update StripeCheckoutModal with Focus Trap
- [ ] Import useFocusTrap hook
- [ ] Add focus trap logic
- [ ] Add role="dialog" attributes
- [ ] Add payment form accessibility

**File:** `/home/fastl/JustLayMe/client/src/components/modals/StripeCheckoutModal.jsx`
**Effort:** 45 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 1.6 Fix Button ARIA Labels
- [ ] Message.jsx: Copy and Delete buttons
- [ ] InputArea.jsx: File attachment button
- [ ] Sidebar.jsx: Footer buttons
- [ ] ChatArea.jsx: Header action buttons
- [ ] All other action buttons

**Effort:** 1 hour
**Owner:** [Assign]
**Status:** ⬜ Not Started

**Checklist per file:**
- [ ] Message.jsx (2 buttons)
- [ ] InputArea.jsx (1 button)
- [ ] Sidebar.jsx (2 buttons)
- [ ] ChatArea.jsx (verify all buttons)
- [ ] Other components (as found)

---

### 1.7 Update Vite Configuration
- [ ] Change `target: 'esnext'` to target array
- [ ] Target: `['es2020', 'edge88', 'firefox87', 'chrome87', 'safari13']`
- [ ] Test build output
- [ ] Verify no breaking changes

**File:** `/home/fastl/JustLayMe/client/vite.config.js` (Line 41)
**Effort:** 30 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 1.8 Install Polyfills
- [ ] Add `core-js` to dependencies
- [ ] Add `regenerator-runtime` to dependencies
- [ ] Add imports to `main.jsx`
- [ ] Test in older browsers

**Files:**
- `/home/fastl/JustLayMe/client/package.json`
- `/home/fastl/JustLayMe/client/src/main.jsx`

**Effort:** 30 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

**Phase 1 Total Effort:** 5-6 hours
**Phase 1 Owner:** [Assign lead]
**Phase 1 Status:** ⬜ Not Started

---

## PHASE 2: HIGH PRIORITY ISSUES (Week 2)

### 2.1 Fix Form Label Associations
- [ ] SettingsModal edit form labels
  - [ ] Character name label
  - [ ] Bio label
  - [ ] Personality label
  - [ ] Avatar label
- [ ] ChatArea form labels
- [ ] InputArea form labels
- [ ] All forms tested

**Files:**
- `/home/fastl/JustLayMe/client/src/components/modals/SettingsModal.jsx`
- `/home/fastl/JustLayMe/client/src/components/chat/InputArea.jsx`
- `/home/fastl/JustLayMe/client/src/components/modals/CharacterCreatorModal.jsx`

**Effort:** 45 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 2.2 Add Error Message Associations
- [ ] InputArea validation messages
- [ ] SettingsModal form errors
- [ ] Add aria-describedby to inputs
- [ ] Add role="alert" to error messages
- [ ] Test with screen reader

**Effort:** 1 hour
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 2.3 Add Keyboard Navigation to Tab Groups
- [ ] SettingsModal tabs
  - [ ] Add handleTabKeyDown handler
  - [ ] Handle Arrow Left/Right keys
  - [ ] Handle Home/End keys
  - [ ] Proper tabIndex management
  - [ ] Test all keys
- [ ] Other tab groups if present

**File:** `/home/fastl/JustLayMe/client/src/components/modals/SettingsModal.jsx`
**Effort:** 1 hour
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 2.4 Add Missing ARIA Attributes to Modals
- [ ] SettingsModal: role="dialog", aria-modal
- [ ] NeuralCharacterBuilder: role="dialog", aria-modal
- [ ] PremiumPaywallModal: role="dialog", aria-modal
- [ ] StripeCheckoutModal: role="dialog", aria-modal
- [ ] All modal titles have IDs
- [ ] All modals linked with aria-labelledby

**Effort:** 30 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 2.5 Update Tab Buttons with ARIA
- [ ] Add role="tablist" to tab container
- [ ] Add role="tab" to each tab button
- [ ] Add aria-selected attribute
- [ ] Add aria-controls linking
- [ ] Add tab panels with role="tabpanel"
- [ ] Test screen reader announcements

**File:** `/home/fastl/JustLayMe/client/src/components/modals/SettingsModal.jsx`
**Effort:** 45 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 2.6 Update Toggle Switches with ARIA
- [ ] All toggle inputs in Settings
- [ ] Add aria-label to checkboxes
- [ ] Add aria-describedby for descriptions
- [ ] Verify label associations
- [ ] Test with screen reader

**File:** `/home/fastl/JustLayMe/client/src/components/modals/SettingsModal.jsx`
**Effort:** 30 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 2.7 Add Main Landmark
- [ ] ChatLayout: wrap ChatArea in <main>
- [ ] Verify semantic structure
- [ ] Test with accessibility tools

**File:** `/home/fastl/JustLayMe/client/src/components/chat/ChatLayout.jsx`
**Effort:** 15 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 2.8 Update Modal Overlay Roles
- [ ] Change overlay divs to role="presentation"
- [ ] Verify they're not interactive
- [ ] Verify focus management

**Files:** All modal files
**Effort:** 20 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

**Phase 2 Total Effort:** 4-5 hours
**Phase 2 Owner:** [Assign lead]
**Phase 2 Status:** ⬜ Not Started

---

## PHASE 3: MEDIUM PRIORITY ISSUES (Week 3-4)

### 3.1 Update Text Contrast Colors
- [ ] Update `$text-tertiary` in variables.scss
- [ ] Update placeholder color in global.scss
- [ ] Verify contrast ratios (4.5:1 minimum for AA)
- [ ] Test all text colors
- [ ] Verify disabled button text contrast

**Files:**
- `/home/fastl/JustLayMe/client/src/styles/variables.scss`
- `/home/fastl/JustLayMe/client/src/styles/global.scss`

**Effort:** 30 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 3.2 Add prefers-reduced-motion Support
- [ ] LightRays.jsx/css
- [ ] FallingText.jsx/css
- [ ] RotatingText.jsx/css
- [ ] Dock.jsx/css
- [ ] Modal animations
- [ ] Transition animations
- [ ] Test with reduced motion enabled

**Effort:** 1-1.5 hours
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 3.3 Improve Semantic HTML
- [ ] Convert message divs to articles
- [ ] Add section tags where appropriate
- [ ] Add aside tags for sidebars
- [ ] Verify heading hierarchy

**Effort:** 1 hour
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 3.4 Add Live Regions for Chat
- [ ] Add role="log" to MessageList
- [ ] Add aria-live="polite"
- [ ] Add aria-label
- [ ] Test message announcements

**File:** `/home/fastl/JustLayMe/client/src/components/chat/MessageList.jsx`
**Effort:** 30 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 3.5 Add Fieldset for Grouped Inputs
- [ ] Settings toggle groups
- [ ] Character form groups
- [ ] Any other logical groupings

**Effort:** 45 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 3.6 Audit Button Sizes
- [ ] Verify all buttons meet 44x44px minimum
- [ ] Update CSS with min-height/min-width
- [ ] Special handling for icon buttons
- [ ] Test on mobile

**Files:**
- `/home/fastl/JustLayMe/client/src/styles/global.scss`
- Individual component SCSS files

**Effort:** 45 minutes
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

### 3.7 Add Skip Links
- [ ] Create skip to main content link
- [ ] Create skip to chat messages link
- [ ] Make hidden until focused
- [ ] Test keyboard navigation

**Effort:** 1 hour
**Owner:** [Assign]
**Status:** ⬜ Not Started

---

**Phase 3 Total Effort:** 5-6 hours
**Phase 3 Owner:** [Assign lead]
**Phase 3 Status:** ⬜ Not Started

---

## PHASE 4: TESTING & VERIFICATION (Ongoing)

### 4.1 Keyboard Testing
- [ ] Tab through entire application
- [ ] Shift+Tab goes backward
- [ ] ESC closes modals
- [ ] Enter activates buttons
- [ ] Space activates buttons and checkboxes
- [ ] Arrow keys work in selects and tabs
- [ ] Focus visible on all elements
- [ ] Focus order is logical

**Effort:** 2 hours
**Owner:** [QA Lead]
**Status:** ⬜ Not Started

---

### 4.2 Screen Reader Testing
- [ ] NVDA testing
  - [ ] Modal announced as dialog
  - [ ] Form labels announced
  - [ ] Error messages announced
  - [ ] Tab navigation works
  - [ ] All buttons labeled

- [ ] JAWS testing
  - [ ] Same as NVDA

- [ ] VoiceOver testing (Mac)
  - [ ] Same as NVDA

- [ ] TalkBack testing (Android)
  - [ ] Touch navigation
  - [ ] Button activation

- [ ] VoiceOver testing (iOS)
  - [ ] Touch navigation
  - [ ] Rotor navigation

**Effort:** 3-4 hours
**Owner:** [QA Lead]
**Status:** ⬜ Not Started

---

### 4.3 Browser Compatibility Testing
- [ ] Chrome 87+: Full test
- [ ] Firefox 87+: Full test
- [ ] Safari 13+: Full test
- [ ] Edge 88+: Full test
- [ ] Mobile Safari (iOS 13+)
- [ ] Mobile Chrome (Android)

**Effort:** 3 hours
**Owner:** [QA Lead]
**Status:** ⬜ Not Started

---

### 4.4 Automated Testing Setup
- [ ] Install axe-core
- [ ] Install jest-axe
- [ ] Create test file
- [ ] Add to CI/CD pipeline
- [ ] Configure reporting

**Files:**
- `/home/fastl/JustLayMe/client/package.json`
- New test files

**Effort:** 1.5 hours
**Owner:** [DevOps/QA Lead]
**Status:** ⬜ Not Started

---

### 4.5 Color Contrast Verification
- [ ] Use WebAIM Contrast Checker
- [ ] Verify all text meets AA (4.5:1)
- [ ] Verify large text meets AA (3:1)
- [ ] Test with Color Blind Simulator
- [ ] Document contrast ratios

**Effort:** 1 hour
**Owner:** [QA Lead]
**Status:** ⬜ Not Started

---

### 4.6 Mobile & Touch Testing
- [ ] iPhone/iPad (iOS)
- [ ] Android phones/tablets
- [ ] 44x44px touch targets
- [ ] Zoom works correctly
- [ ] Keyboard on mobile
- [ ] Screen reader on mobile

**Effort:** 2 hours
**Owner:** [QA Lead]
**Status:** ⬜ Not Started

---

### 4.7 Documentation & Training
- [ ] Document all changes
- [ ] Create accessibility guidelines
- [ ] Train team on best practices
- [ ] Set up accessibility checklist for PRs
- [ ] Create testing procedures

**Effort:** 2 hours
**Owner:** [Tech Lead]
**Status:** ⬜ Not Started

---

**Phase 4 Total Effort:** 13-15 hours (over time)
**Phase 4 Owner:** [QA Lead]
**Phase 4 Status:** ⬜ Not Started

---

## SUMMARY

### Timeline
```
Week 1: Phase 1 (Critical) - 5-6 hours
Week 2: Phase 2 (High) - 4-5 hours
Week 3-4: Phase 3 (Medium) - 5-6 hours
Ongoing: Phase 4 (Testing) - 13-15 hours
─────────────────────────────
TOTAL: 27-32 hours (distributed over 4 weeks)
```

### Resource Allocation
- **Frontend Developers:** 2-3 (Phases 1-3)
- **QA/Testing:** 1 (Phase 4)
- **Tech Lead:** 1 (oversight, Phase 4 docs)

### Success Metrics
- [ ] All critical issues resolved
- [ ] All high-priority issues resolved
- [ ] WCAG 2.1 AA compliant
- [ ] Keyboard accessible
- [ ] Screen reader accessible
- [ ] Mobile accessible
- [ ] Browser compatible (ES2020+)
- [ ] Automated testing in CI/CD

### Sign-Off
- [ ] Development Lead: _____________ Date: _____
- [ ] QA Lead: _____________ Date: _____
- [ ] Product Manager: _____________ Date: _____

---

## Notes

### Starting Point
Use this checklist to track implementation progress. Check off items as they're completed and move between statuses:
- ⬜ Not Started
- 🟨 In Progress
- 🟩 Complete
- 🔴 Blocked

### Blockers/Issues
Document any blockers encountered:
```
Date: __________
Issue: __________
Impact: __________
Resolution: __________
```

### Questions/Decisions
```
Question: __________
Decision: __________
Owner: __________
Date: __________
```

---

**Prepared by:** Claude Code
**Date:** November 21, 2025
**Last Updated:** [To be updated by team]
