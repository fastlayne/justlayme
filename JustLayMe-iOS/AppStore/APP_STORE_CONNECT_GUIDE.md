# App Store Connect Configuration Guide

## Complete Setup for JustLayMe iOS App

---

## 1. Prerequisites

Before starting, ensure you have:
- [ ] Apple Developer Program membership ($99/year)
- [ ] Access to App Store Connect (https://appstoreconnect.apple.com)
- [ ] Xcode 15+ installed
- [ ] Valid Apple Distribution certificate
- [ ] App Store provisioning profile

---

## 2. Create App in App Store Connect

### Step 1: Navigate to Apps
1. Go to https://appstoreconnect.apple.com
2. Click "My Apps"
3. Click the "+" button → "New App"

### Step 2: Fill App Information

| Field | Value |
|-------|-------|
| **Platforms** | iOS |
| **Name** | JustLayMe |
| **Primary Language** | English (U.S.) |
| **Bundle ID** | com.justlayme.app |
| **SKU** | JUSTLAYME001 |
| **User Access** | Full Access |

---

## 3. App Information Tab

### General Information

| Field | Value |
|-------|-------|
| **Subtitle** | AI Chat Companion |
| **Category** | Social Networking |
| **Secondary Category** | Entertainment |
| **Content Rights** | Does not contain third-party content requiring rights |
| **Age Rating** | 17+ (see rating questionnaire below) |

### Age Rating Questionnaire Answers

| Question | Answer |
|----------|--------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Violence | None |
| Profanity or Crude Humor | Infrequent/Mild |
| Mature/Suggestive Themes | Frequent/Intense |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use | None |
| Simulated Gambling | None |
| Sexual Content and Nudity | Infrequent/Mild |
| Unrestricted Web Access | No |
| Gambling and Contests | None |

**Result: 17+ Rating**

---

## 4. Pricing and Availability

### Pricing
| Setting | Value |
|---------|-------|
| **Price Schedule** | Free |
| **In-App Purchases** | Yes |

### Availability
| Setting | Value |
|---------|-------|
| **Countries** | All territories (or select specific) |
| **Release Date** | Manual release after approval |
| **Pre-Order** | No |

---

## 5. In-App Purchases Configuration

### Create Products in App Store Connect

#### Monthly Subscription
| Field | Value |
|-------|-------|
| **Reference Name** | Premium Monthly |
| **Product ID** | com.justlayme.premium.monthly |
| **Type** | Auto-Renewable Subscription |
| **Subscription Group** | JustLayMe Premium |
| **Subscription Duration** | 1 Month |
| **Price** | $9.99 (Tier 10) |
| **Display Name** | Monthly Premium |
| **Description** | Unlimited access to all AI models, full chat history, character creation, and priority support. |

#### Yearly Subscription
| Field | Value |
|-------|-------|
| **Reference Name** | Premium Yearly |
| **Product ID** | com.justlayme.premium.yearly |
| **Type** | Auto-Renewable Subscription |
| **Subscription Group** | JustLayMe Premium |
| **Subscription Duration** | 1 Year |
| **Price** | $79.99 (Tier 80) |
| **Display Name** | Yearly Premium |
| **Description** | Save 33%! Unlimited access to all AI models, full chat history, character creation, priority support, and exclusive yearly badge. |

#### Lifetime Purchase
| Field | Value |
|-------|-------|
| **Reference Name** | Premium Lifetime |
| **Product ID** | com.justlayme.premium.lifetime |
| **Type** | Non-Consumable |
| **Price** | $199.00 (Tier 199) |
| **Display Name** | Lifetime Premium |
| **Description** | One-time purchase for lifetime access to all premium features. Never pay again! |

### Subscription Group Settings
- **Group Name**: JustLayMe Premium
- **Upgrade/Downgrade Order**: Lifetime > Yearly > Monthly

---

## 6. App Privacy

### Data Collection Disclosure

#### Data Linked to User
| Data Type | Purpose |
|-----------|---------|
| **Email Address** | Account creation, authentication |
| **Name** | App functionality, personalization |
| **User ID** | App functionality |
| **Purchase History** | App functionality |

#### Data Not Linked to User
| Data Type | Purpose |
|-----------|---------|
| **Crash Data** | App functionality |
| **Performance Data** | Analytics |
| **Usage Data** | Analytics |

### Tracking
- **Does your app track users?** No
- **Reason**: We do not track users across apps/websites for advertising

---

## 7. Version Information (1.0)

### What's New in This Version
```
Welcome to JustLayMe! 🎉

• Chat with multiple AI personalities
• Free unlimited access to Layme V1 model
• Premium models for subscribers
• Create custom AI characters
• Dark mode interface
• Secure cloud sync
```

### Promotional Text
```
Chat with AI companions that understand you. JustLayMe offers multiple AI personalities, from friendly conversation partners to creative storytellers. Free to start, premium to unlock everything.
```

### Description
```
JustLayMe is your AI chat companion app featuring multiple AI personalities designed for engaging conversations.

FEATURES:
• Multiple AI Models - Choose from Layme V1 (free), LayMe Uncensored, Mythomax Roleplay, and FastLayMe
• Character Creation - Premium users can create custom AI personalities
• Chat History - Save and revisit your favorite conversations
• Dark Mode - Beautiful dark interface that's easy on the eyes
• Cloud Sync - Your conversations sync across devices

FREE FEATURES:
• Unlimited messages with Layme V1
• 3 free messages per premium model
• Basic conversation history

PREMIUM FEATURES ($9.99/month, $79.99/year, or $199 lifetime):
• Unlimited access to all AI models
• Full conversation history & search
• Create custom AI characters
• Priority response times
• Early access to new features

Privacy-focused: Your conversations are encrypted and we never sell your data.

Download now and start chatting!
```

### Keywords
```
ai chat, chatbot, ai companion, virtual friend, ai assistant, roleplay, character ai, chat bot, ai conversation, virtual companion
```

### Support URL
```
https://justlay.me/support
```

### Marketing URL
```
https://justlay.me
```

### Privacy Policy URL
```
https://justlay.me/privacy
```

---

## 8. Build Upload

### Archive and Upload

```bash
# 1. Set version and build numbers in Xcode
# Version: 1.0.0
# Build: 1

# 2. Select "Any iOS Device (arm64)" as destination

# 3. Product → Archive

# 4. In Organizer, click "Distribute App"
#    - Select "App Store Connect"
#    - Choose "Upload"
#    - Enable: Upload symbols, Manage signing
#    - Click Upload
```

### Build Processing
- Builds typically process in 15-30 minutes
- Check email for "build processing complete" notification
- Build will appear in App Store Connect under TestFlight

---

## 9. App Review Information

### Contact Information
| Field | Value |
|-------|-------|
| **First Name** | [Your First Name] |
| **Last Name** | [Your Last Name] |
| **Phone** | [Your Phone Number] |
| **Email** | support@justlay.me |

### Demo Account
| Field | Value |
|-------|-------|
| **Required** | Yes (for login testing) |
| **Username** | demo@justlay.me |
| **Password** | DemoPassword123! |

### Notes for Review
```
Thank you for reviewing JustLayMe!

DEMO ACCOUNT:
Email: demo@justlay.me
Password: DemoPassword123!

KEY FEATURES TO TEST:
1. Login/Registration - Use demo account or create new
2. Chat - Send messages to any AI character
3. Character Selection - Tap characters at top of chat
4. Premium Features - Try premium models (3 free messages)
5. Subscription - View plans in Profile → Upgrade

NOTES:
- AI responses are generated by our backend servers
- App requires internet connection
- Premium features require subscription
- Guest mode available for quick testing

Please contact support@justlay.me with any questions.
```

---

## 10. Export Compliance

### Encryption
| Question | Answer |
|----------|--------|
| **Does your app use encryption?** | Yes |
| **Is it exempt?** | Yes - Standard HTTPS/TLS only |
| **Exempt encryption types** | (a) Authentication, (b) Standard protocols |

Add to Info.plist:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## 11. Submission Checklist

### Before Submitting
- [ ] All app metadata complete
- [ ] Screenshots uploaded (all device sizes)
- [ ] App Preview video (optional)
- [ ] Privacy policy URL accessible
- [ ] Support URL accessible
- [ ] Demo account credentials provided
- [ ] Build uploaded and processed
- [ ] In-app purchases configured
- [ ] Age rating questionnaire complete
- [ ] Export compliance answered
- [ ] App Review notes written

### Submit for Review
1. Select build in "Build" section
2. Click "Add for Review"
3. Answer final questions
4. Click "Submit to App Review"

---

## 12. Post-Submission

### Expected Timeline
- **Initial Review**: 24-48 hours typical
- **Rejection Response**: Address issues, resubmit
- **Approval**: Automatic or manual release

### Common Rejection Reasons to Avoid
1. ❌ Crashes or bugs
2. ❌ Broken links (privacy policy, support)
3. ❌ Incomplete metadata
4. ❌ Invalid demo account
5. ❌ Missing purpose strings in Info.plist
6. ❌ Inaccurate screenshots
7. ❌ Guideline 4.2 (minimum functionality)

### After Approval
1. Release manually or automatically
2. Monitor crash reports in Xcode Organizer
3. Respond to user reviews
4. Plan version 1.1 updates

---

## Quick Reference - Bundle IDs

| Item | Identifier |
|------|------------|
| App | com.justlayme.app |
| Monthly Sub | com.justlayme.premium.monthly |
| Yearly Sub | com.justlayme.premium.yearly |
| Lifetime | com.justlayme.premium.lifetime |
| App Group | group.com.justlayme |
