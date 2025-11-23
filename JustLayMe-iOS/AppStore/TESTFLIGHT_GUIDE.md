# TestFlight Setup and Distribution Guide

## Complete Guide for JustLayMe Beta Testing

---

## 1. Prerequisites

### Required
- [ ] Apple Developer Program membership ($99/year)
- [ ] App created in App Store Connect
- [ ] Valid distribution certificate
- [ ] Valid provisioning profile
- [ ] Xcode 15+ installed

### Recommended
- [ ] At least 5 internal testers
- [ ] At least 10 external testers
- [ ] Test devices (various iPhone models)
- [ ] Beta feedback system (email or form)

---

## 2. Build Preparation

### Step 1: Version and Build Numbers

In Xcode, set the following in your target's General tab:

```
Version: 1.0.0  (CFBundleShortVersionString)
Build: 1        (CFBundleVersion)
```

**Rules**:
- Version follows semantic versioning (1.0.0)
- Build number must increment with each upload
- Build numbers can be simple integers (1, 2, 3...)

### Step 2: Select Destination

```
Product → Destination → Any iOS Device (arm64)
```

### Step 3: Archive the Build

```
Product → Archive
```

Wait for archiving to complete (2-5 minutes).

### Step 4: Upload to App Store Connect

1. In Xcode Organizer, select the archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Choose "Upload"
5. Options:
   - ✅ Upload your app's symbols
   - ✅ Manage Version and Build Number
   - ✅ Automatically manage signing
6. Click "Upload"

---

## 3. App Store Connect Setup

### Navigate to TestFlight

1. Go to https://appstoreconnect.apple.com
2. Select "JustLayMe"
3. Click "TestFlight" tab

### Build Processing

After upload:
- Build appears as "Processing" (15-30 minutes)
- Email notification when processing complete
- Build ready for testing

---

## 4. Internal Testing

### What is Internal Testing?
- Up to 100 testers
- Must be App Store Connect users
- Builds available immediately (no review)
- Ideal for team members and stakeholders

### Add Internal Testers

1. Go to TestFlight → Internal Testing
2. Click "+" next to App Store Connect Users
3. Add team members by email
4. Assign to a testing group

### Create Internal Testing Group

1. Click "+" next to Internal Testing
2. Name: "Core Team" or "Alpha Testers"
3. Add members
4. Enable builds for testing

### Internal Tester Requirements
- Apple ID
- Must accept TestFlight invitation
- iOS 14+ device
- TestFlight app installed

---

## 5. External Testing

### What is External Testing?
- Up to 10,000 testers per app
- Requires Beta App Review (24-48 hours first time)
- Anyone with email can join
- Best for public betas

### Create External Testing Group

1. Go to TestFlight → External Testing
2. Click "+" to create new group
3. Name: "Beta Testers" or "Public Beta"

### Add Testers

**By Email**:
1. Click "Testers" tab
2. Click "+" → "Add New Testers"
3. Enter email addresses (comma-separated)
4. Add up to 10,000 testers

**By Public Link**:
1. Click "Enable Public Link"
2. Copy the link
3. Share on website, social media, etc.
4. Set limit (e.g., 1,000 testers)

---

## 6. Beta App Review

### First External Build

First external build requires Beta App Review:
- Takes 24-48 hours typically
- Faster than full App Review
- Checks for major issues only

### What to Provide

**Test Information** (required):
```
Email: beta@justlay.me
First Name: Beta
Last Name: Tester
Phone: +1-555-0123

Feedback Email: feedback@justlay.me
```

**What to Test** (required):
```
Thank you for testing JustLayMe!

KEY FEATURES TO TEST:
1. Account creation/login
2. Chat with AI characters
3. Switch between characters
4. View chat history
5. Premium subscription flow

KNOWN ISSUES:
- None currently

FEEDBACK:
Please send feedback to feedback@justlay.me or use the in-app feedback button.
```

**Beta App Description** (optional but recommended):
```
JustLayMe is an AI chat companion app. Chat with multiple AI personalities, create custom characters, and enjoy engaging conversations.

This beta version includes all core features. We're looking for feedback on:
- App stability
- AI response quality
- User experience
- Any bugs or issues
```

---

## 7. Build Groups and Versions

### Managing Multiple Builds

1. Upload new builds with incremented build numbers
2. Assign builds to specific groups
3. Keep older builds available if needed

### Automatic Distribution

Enable for continuous deployment:
1. Go to TestFlight → Build → Manage
2. Enable "Automatically notify testers"
3. All testers get new builds automatically

---

## 8. TestFlight Tester Experience

### Installation Steps (for testers)

1. Receive invitation email
2. Open on iOS device
3. Tap "View in TestFlight"
4. Install TestFlight app (if not installed)
5. Accept invitation
6. Install app

### Tester Feedback

Testers can:
- Take screenshots (auto-attached to feedback)
- Submit feedback via TestFlight app
- Report crashes (automatic)
- Rate the beta

---

## 9. Monitoring and Analytics

### View in App Store Connect

**Crashes**:
- TestFlight → Crashes
- View stack traces
- See affected devices/OS versions

**Feedback**:
- TestFlight → Feedback
- Read tester comments
- View attached screenshots

**Installs**:
- TestFlight → Testers & Groups
- See install counts
- View tester engagement

---

## 10. Build Expiration

### Important!
- TestFlight builds expire after **90 days**
- Testers must update before expiration
- Plan to release or upload new build before expiry

### Tracking Expiration

1. App Store Connect shows expiration dates
2. Email notifications before expiry
3. Plan regular build updates

---

## 11. Moving to Production

### When Ready to Release

1. Ensure final testing complete
2. Create App Store version submission
3. Use same build from TestFlight
4. Complete App Store metadata
5. Submit for App Review

### Transition Checklist

- [ ] All critical bugs fixed
- [ ] Beta tester feedback addressed
- [ ] Performance acceptable
- [ ] No critical crashes
- [ ] All features working
- [ ] Ready for public release

---

## 12. Best Practices

### Testing Strategy

| Phase | Group | Focus |
|-------|-------|-------|
| Alpha | Internal | Core functionality, crashes |
| Closed Beta | 50-100 external | Usability, feedback |
| Open Beta | 500+ external | Scale, performance |
| Release Candidate | All | Final validation |

### Communication

1. **Welcome Email**: Explain what to test
2. **Weekly Updates**: Share progress
3. **Changelog**: What's new in each build
4. **Thank You**: Acknowledge valuable feedback

### Feedback Collection

- In-app feedback form
- Email address for reports
- Discord/Slack community
- TestFlight's built-in feedback

---

## 13. Troubleshooting

### Common Issues

**Build not appearing**:
- Check email for processing completion
- Wait up to 30 minutes
- Check for provisioning issues

**Tester can't install**:
- Verify correct email
- Check TestFlight app version
- Ensure iOS version supported

**Beta review rejected**:
- Read rejection reason carefully
- Fix issues
- Resubmit with explanation

**Crashes increasing**:
- Check crash reports in Xcode Organizer
- Use Crashlytics for detailed analytics
- Prioritize fixes for common crashes

---

## 14. Quick Reference

### TestFlight Limits

| Limit | Value |
|-------|-------|
| Internal testers | 100 |
| External testers | 10,000 |
| Testing groups | 200 |
| Build expiration | 90 days |
| App groups | Unlimited |

### Useful URLs

- App Store Connect: https://appstoreconnect.apple.com
- TestFlight for Users: https://testflight.apple.com
- Apple Developer Forums: https://developer.apple.com/forums

---

## 15. Sample Invitation Email

Send this to beta testers:

```
Subject: You're Invited to Test JustLayMe! 🎉

Hi there!

You've been selected to beta test JustLayMe, our new AI chat companion app.

HOW TO JOIN:
1. Check for an email from TestFlight
2. Open on your iPhone
3. Tap "View in TestFlight"
4. Install and start testing!

WHAT TO TEST:
- Create an account and sign in
- Chat with different AI characters
- Try the premium features (free during beta)
- Report any bugs or issues

GIVE FEEDBACK:
- Use the TestFlight app's feedback feature
- Or email us at feedback@justlay.me

Thank you for helping us make JustLayMe amazing!

The JustLayMe Team
```
