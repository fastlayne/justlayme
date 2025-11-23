# Quick Fixes for Critical Accessibility Issues
**Priority: Implement ASAP**

---

## 1. Add Focus Trap Hook for Modals

Create `/home/fastl/JustLayMe/client/src/hooks/useFocusTrap.js`:

```javascript
import { useEffect, useRef } from 'react'

export function useFocusTrap(isOpen, onClose) {
  const containerRef = useRef(null)

  useEffect(() => {
    if (!isOpen || !containerRef.current) return

    const container = containerRef.current

    // Move focus into modal on open
    const firstFocusable = container.querySelector(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    if (firstFocusable) {
      firstFocusable.focus()
    }

    // Trap focus within modal
    const handleKeyDown = (e) => {
      if (e.key !== 'Tab') return

      const focusables = Array.from(
        container.querySelectorAll(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        )
      )

      if (focusables.length === 0) return

      const firstFocusable = focusables[0]
      const lastFocusable = focusables[focusables.length - 1]
      const activeEl = document.activeElement

      if (e.shiftKey) {
        // Shift + Tab
        if (activeEl === firstFocusable) {
          e.preventDefault()
          lastFocusable.focus()
        }
      } else {
        // Tab
        if (activeEl === lastFocusable) {
          e.preventDefault()
          firstFocusable.focus()
        }
      }
    }

    // Handle Escape key
    const handleKeyUp = (e) => {
      if (e.key === 'Escape') {
        onClose()
      }
    }

    container.addEventListener('keydown', handleKeyDown)
    container.addEventListener('keyup', handleKeyUp)

    return () => {
      container.removeEventListener('keydown', handleKeyDown)
      container.removeEventListener('keyup', handleKeyUp)
    }
  }, [isOpen, onClose])

  return containerRef
}
```

---

## 2. Update All Modal Components

### SettingsModal.jsx

```jsx
import { useState, useRef } from 'react'
import { useFocusTrap } from '@/hooks/useFocusTrap'
import { useAuth } from '@/hooks/useAuth'
// ... other imports

export default function SettingsModal({ modalId, onClose }) {
  const modalRef = useFocusTrap(true, onClose)
  const triggerRef = useRef(null)

  // ... rest of component

  const handleClose = () => {
    // Return focus to triggering element
    setTimeout(() => {
      const button = document.querySelector('[data-modal-trigger="settings"]')
      button?.focus()
    }, 0)
    onClose()
  }

  return (
    <div className="modal-overlay" onClick={handleClose} role="presentation">
      <div
        className="modal-content settings-modal"
        onClick={(e) => e.stopPropagation()}
        ref={modalRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="settings-modal-title"
      >
        <div className="modal-header">
          <h2 id="settings-modal-title">Settings</h2>
          <button
            className="modal-close"
            onClick={handleClose}
            aria-label="Close settings dialog"
          >
            ✕
          </button>
        </div>
        {/* Rest of modal content */}
      </div>
    </div>
  )
}
```

---

## 3. Fix All Button ARIA Labels

### Message.jsx - Line 54-61

**BEFORE:**
```jsx
<button className="action-btn" title="Copy message">
  📋
</button>
<button className="action-btn" title="Delete message">
  🗑️
</button>
```

**AFTER:**
```jsx
<button
  className="action-btn"
  aria-label="Copy message to clipboard"
  title="Copy message"
>
  📋
</button>
<button
  className="action-btn"
  aria-label="Delete message"
  title="Delete message"
>
  🗑️
</button>
```

---

### InputArea.jsx - Line 224-231

**BEFORE:**
```jsx
<button
  className="action-button secondary"
  title="Attach file (images only, max 5MB)"
  onClick={() => fileInputRef.current?.click()}
>
  📎
</button>
```

**AFTER:**
```jsx
<button
  className="action-button secondary"
  aria-label="Attach image file (max 5MB)"
  title="Attach file (images only, max 5MB)"
  onClick={() => fileInputRef.current?.click()}
>
  📎
</button>
```

---

### Sidebar.jsx - Line 327-329

**BEFORE:**
```jsx
<button className="footer-btn" onClick={handleSettings}>⚙️ Settings</button>
<button className="footer-btn" onClick={handleLogout}>🚪 Logout</button>
```

**AFTER:**
```jsx
<button
  className="footer-btn"
  aria-label="Open settings"
  onClick={handleSettings}
>
  ⚙️ Settings
</button>
<button
  className="footer-btn"
  aria-label="Logout"
  onClick={handleLogout}
>
  🚪 Logout
</button>
```

---

## 4. Fix Form Label Associations

### SettingsModal.jsx - Line 323-346 (Edit form)

**BEFORE:**
```jsx
<div className="form-group">
  <label>Name</label>
  <input
    type="text"
    value={editingCharacter.name}
    onChange={(e) => setEditingCharacter({...editingCharacter, name: e.target.value})}
  />
</div>
```

**AFTER:**
```jsx
<div className="form-group">
  <label htmlFor="char-name">Name</label>
  <input
    id="char-name"
    type="text"
    value={editingCharacter.name}
    onChange={(e) => setEditingCharacter({...editingCharacter, name: e.target.value})}
  />
</div>
<div className="form-group">
  <label htmlFor="char-bio">Bio</label>
  <textarea
    id="char-bio"
    value={editingCharacter.bio}
    onChange={(e) => setEditingCharacter({...editingCharacter, bio: e.target.value})}
    rows={3}
  />
</div>
<div className="form-group">
  <label htmlFor="char-personality">Personality</label>
  <textarea
    id="char-personality"
    value={editingCharacter.personality}
    onChange={(e) => setEditingCharacter({...editingCharacter, personality: e.target.value})}
    rows={2}
  />
</div>
```

---

## 5. Add Keyboard Navigation to Tab Groups

### SettingsModal.jsx - Line 144-185 (Settings tabs)

**ADD THIS HANDLER:**
```javascript
const TABS = ['account', 'characters', 'ai-settings', 'chat-settings', 'preferences', 'data', 'premium']

const handleTabKeyDown = (e) => {
  const currentIndex = TABS.indexOf(activeTab)
  let newIndex = currentIndex

  if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
    e.preventDefault()
    newIndex = (currentIndex + 1) % TABS.length
  } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
    e.preventDefault()
    newIndex = (currentIndex - 1 + TABS.length) % TABS.length
  } else if (e.key === 'Home') {
    e.preventDefault()
    newIndex = 0
  } else if (e.key === 'End') {
    e.preventDefault()
    newIndex = TABS.length - 1
  } else {
    return
  }

  setActiveTab(TABS[newIndex])
}
```

**THEN UPDATE TAB BUTTONS:**
```jsx
<div role="tablist" className="settings-sidebar">
  <button
    key={tab}
    role="tab"
    aria-selected={activeTab === tab}
    aria-controls={`${tab}-panel`}
    id={`${tab}-tab`}
    className={`settings-tab ${activeTab === tab ? 'active' : ''}`}
    onClick={() => setActiveTab(tab)}
    onKeyDown={handleTabKeyDown}
    tabIndex={activeTab === tab ? 0 : -1}
  >
    {tabLabel}
  </button>
</div>

{/* Add panel wrapper */}
<div
  role="tabpanel"
  id={`${tab}-panel`}
  aria-labelledby={`${tab}-tab`}
  className="settings-content"
>
  {/* Tab content */}
</div>
```

---

## 6. Fix Vite Browser Target

### vite.config.js - Line 41

**BEFORE:**
```javascript
build: {
  outDir: 'dist',
  sourcemap: false,
  minify: 'terser',
  target: 'esnext',
```

**AFTER:**
```javascript
build: {
  outDir: 'dist',
  sourcemap: false,
  minify: 'terser',
  target: ['es2020', 'edge88', 'firefox87', 'chrome87', 'safari13'],
```

---

## 7. Update Text Contrast Colors

### src/styles/variables.scss - Lines 22-24

**BEFORE:**
```scss
$text-primary: #ffffff;     // White (good contrast)
$text-secondary: #a0aec0;   // ~51% gray
$text-tertiary: #64748b;    // ~42% gray - FAILS AA
```

**AFTER:**
```scss
$text-primary: #ffffff;     // White (good contrast) - 21:1
$text-secondary: #a0aec0;   // ~51% gray - 8.6:1 (meets AA)
$text-tertiary: #888888;    // Increased lightness - 5.8:1 (better)
```

### global.scss - Placeholder text (Line 164-166)

**BEFORE:**
```scss
&::placeholder {
  color: $text-tertiary;
}
```

**AFTER:**
```scss
&::placeholder {
  color: #999999;  // Better contrast
  opacity: 1;
}
```

---

## 8. Add Prefers-Reduced-Motion to Animations

### Add to each animated component's SCSS:

```scss
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    transition-delay: 0ms !important;
  }
}
```

---

## 9. Add Main Landmark

### ChatLayout.jsx - Line 50-60

**BEFORE:**
```jsx
return (
  <div className="chat-layout">
    {/* Left Sidebar */}
    <Sidebar />

    {/* Main Chat Area */}
    <ChatArea />
  </div>
)
```

**AFTER:**
```jsx
return (
  <div className="chat-layout">
    {/* Left Sidebar */}
    <Sidebar />

    {/* Main Chat Area */}
    <main className="chat-main">
      <ChatArea />
    </main>
  </div>
)
```

---

## 10. Add Missing Role Attributes

### SettingsModal.jsx - Modal wrapper (Line 135)

**BEFORE:**
```jsx
<div className="modal-overlay" onClick={onClose}>
  <div className="modal-content settings-modal" onClick={(e) => e.stopPropagation()}>
```

**AFTER:**
```jsx
<div className="modal-overlay" onClick={onClose} role="presentation">
  <div
    className="modal-content settings-modal"
    onClick={(e) => e.stopPropagation()}
    role="dialog"
    aria-modal="true"
    aria-labelledby="settings-modal-title"
  >
```

---

## Testing Checklist

After implementing these fixes, test:

- [ ] Tab through entire app - all interactive elements focusable
- [ ] Tab through modals - focus trapped, ESC key works
- [ ] All buttons have aria-labels or visible text
- [ ] Modal titles have ids matching aria-labelledby
- [ ] Form inputs have labels with htmlFor
- [ ] Settings tabs respond to arrow keys
- [ ] Color contrast passes WCAG AA
- [ ] Animations respect prefers-reduced-motion
- [ ] Screen reader announces modal as dialog
- [ ] Focus returns to button after modal closes

---

## Estimated Implementation Time

- Focus trap hook: 30 minutes
- Modal updates (3 modals): 1 hour
- Button aria-labels: 30 minutes
- Form label fixes: 45 minutes
- Tab keyboard navigation: 1 hour
- Vite config: 10 minutes
- Color updates: 15 minutes
- prefers-reduced-motion: 1 hour
- Landmark additions: 20 minutes
- Testing: 2 hours

**Total: ~7-8 hours**

---

## Related Files to Update

1. `/home/fastl/JustLayMe/client/src/hooks/useFocusTrap.js` (NEW)
2. `/home/fastl/JustLayMe/client/src/components/modals/SettingsModal.jsx`
3. `/home/fastl/JustLayMe/client/src/components/modals/NeuralCharacterBuilder.jsx`
4. `/home/fastl/JustLayMe/client/src/components/modals/PremiumPaywallModal.jsx`
5. `/home/fastl/JustLayMe/client/src/components/modals/StripeCheckoutModal.jsx`
6. `/home/fastl/JustLayMe/client/src/components/chat/Message.jsx`
7. `/home/fastl/JustLayMe/client/src/components/chat/InputArea.jsx`
8. `/home/fastl/JustLayMe/client/src/components/chat/Sidebar.jsx`
9. `/home/fastl/JustLayMe/client/src/components/chat/ChatLayout.jsx`
10. `/home/fastl/JustLayMe/client/src/styles/variables.scss`
11. `/home/fastl/JustLayMe/client/src/styles/global.scss`
12. `/home/fastl/JustLayMe/client/vite.config.js`
13. All animation component SCSS files

---

## Resources

- [MDN: Focus Management](https://developer.mozilla.org/en-US/docs/Web/Accessibility/Understanding_WCAG/Keyboard#focus_management)
- [WAI-ARIA Dialog Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialogmodal/)
- [WCAG 2.1 Conformance](https://www.w3.org/WAI/WCAG21/quickref/)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
