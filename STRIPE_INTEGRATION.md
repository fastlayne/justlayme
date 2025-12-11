# Stripe Payment Integration - JustLayMe
**Status**: ✅ FULLY CONFIGURED AND OPERATIONAL
**Last Updated**: November 17, 2025

---

## ✅ CURRENT STATUS

### Backend Integration
- ✅ Stripe SDK initialized (v18.2.1)
- ✅ All payment endpoints active
- ✅ Webhook handler configured
- ✅ Live API keys configured
- ✅ All price IDs configured

### Configuration
- ✅ Environment variables migrated
- ✅ Config validator active
- ✅ CSP headers allow Stripe.js
- ✅ Rate limiting on payment endpoints (10/hour)

---

## 🔑 ENVIRONMENT VARIABLES (CURRENT)

All Stripe keys are already configured in `/home/fastl/JustLayMe/.env`:

```bash
STRIPE_SECRET_KEY=sk_live_51RaZdFBgA5bvPz6v...  # Live key ✅
STRIPE_PUBLISHABLE_KEY=pk_live_51RaZdFBgA5bvPz6v...  # Live key ✅
STRIPE_WEBHOOK_SECRET=whsec_a4bb5791322e45ba...  # Webhook secret ✅

# Price IDs
STRIPE_PREMIUM_PRICE_ID=price_1RdrK9BgA5bvPz6vKXDnAjea  # Legacy
STRIPE_PRICE_MONTHLY=price_1RdrK8BgA5bvPz6vJVcPXL38    # $9.99/month
STRIPE_PRICE_YEARLY=price_1RdrK9BgA5bvPz6vxb2RwFge     # $75/year
STRIPE_PRICE_LIFETIME=price_1RdrK9BgA5bvPz6vKXDnAjea   # $150 one-time
```

---

## 💰 PRICING STRUCTURE

| Plan | Price | Billing | Stripe Price ID |
|------|-------|---------|-----------------|
| **Monthly** | $9.99 | Recurring | `price_1RdrK8BgA5bvPz6vJVcPXL38` |
| **Yearly** | $75.00 | Recurring (33% savings) | `price_1RdrK9BgA5bvPz6vxb2RwFge` |
| **Lifetime** | $150.00 | One-time payment | `price_1RdrK9BgA5bvPz6vKXDnAjea` |

---

## 🎯 ACTIVE PAYMENT ENDPOINTS

All endpoints are located in `/home/fastl/JustLayMe/src/ai-server.js`:

### 1. Get Stripe Configuration
```
GET /api/stripe-config
```
**Returns**: Publishable key, price IDs, and price details from Stripe API

**Example Response**:
```json
{
  "publishableKey": "pk_live_51RaZdFBgA5bvPz6v...",
  "priceMonthly": "price_1RdrK8BgA5bvPz6vJVcPXL38",
  "priceYearly": "price_1RdrK9BgA5bvPz6vxb2RwFge",
  "priceLifetime": "price_1RdrK9BgA5bvPz6vKXDnAjea",
  "available": true,
  "prices": {
    "monthly": {
      "id": "price_1RdrK8BgA5bvPz6vJVcPXL38",
      "amount": 999,
      "currency": "USD",
      "interval": "month"
    }
  }
}
```

### 2. Create Checkout Session
```
POST /api/stripe-checkout
```
**Body**:
```json
{
  "priceId": "price_1RdrK8BgA5bvPz6vJVcPXL38",
  "email": "user@example.com",
  "successUrl": "https://justlay.me/chat?premium=success",
  "cancelUrl": "https://justlay.me/chat?premium=cancelled"
}
```

**Returns**: Stripe checkout session URL for redirect

### 3. Create Payment Intent (Embedded Checkout)
```
POST /api/create-payment-intent
```
**Body**:
```json
{
  "priceId": "price_1RdrK8BgA5bvPz6vJVcPXL38",
  "email": "user@example.com"
}
```

**Returns**: Client secret for Stripe Elements integration

### 4. Create Subscription
```
POST /api/create-subscription
```
**Body**:
```json
{
  "plan": "monthly",  // "monthly", "yearly", or "lifetime"
  "email": "user@example.com",
  "paymentMethodId": "pm_..."
}
```

**Handles**: Both recurring subscriptions and one-time lifetime payments

### 5. Cancel Subscription
```
POST /api/cancel-subscription
```
**Body**:
```json
{
  "subscriptionId": "sub_..."
}
```

**Behavior**: Sets `cancel_at_period_end = true` (access until period ends)

### 6. Check Subscription Status
```
GET /api/subscription-status/:email
```

**Returns**: Subscription status for user by email

### 7. Stripe Webhooks
```
POST /api/webhooks/stripe
```

**Handles Events**:
- `customer.subscription.created` - Updates database with new subscription
- `customer.subscription.updated` - Updates subscription status
- `customer.subscription.deleted` - Revokes premium access
- `invoice.payment_succeeded` - Records successful payment
- `invoice.payment_failed` - Marks subscription as past_due

**Security**: Validates webhook signature with `STRIPE_WEBHOOK_SECRET`

---

## 🔒 SECURITY FEATURES

### Content Security Policy (CSP)
Stripe.js domains are whitelisted in CSP headers:
```javascript
script-src 'self' 'unsafe-inline' https://js.stripe.com
connect-src 'self' https://api.stripe.com
frame-src https://js.stripe.com
```

### Rate Limiting
Payment endpoints are rate-limited to **10 requests per hour per IP**

### Webhook Signature Verification
All webhook requests verify the `stripe-signature` header

### Input Validation
- Email format validation
- Price ID validation (must start with `price_`)
- Subscription ID validation (must start with `sub_`)

---

## 📦 FRONTEND INTEGRATION (TODO)

### What Needs to be Implemented in New React Frontend

1. **Create Premium/Pricing Page Component**
   - Display three pricing tiers (Monthly, Yearly, Lifetime)
   - Show feature comparison
   - Call `/api/stripe-config` to get current prices
   - Handle payment button clicks

2. **Integrate Stripe Elements**
   - Load Stripe.js from CDN
   - Initialize Stripe with publishable key
   - Create payment form with Card Element
   - Handle payment confirmation

3. **Payment Flow Components**
   - `PremiumPage.jsx` - Pricing tiers and upgrade CTA
   - `CheckoutModal.jsx` - Payment form modal
   - `PaymentSuccess.jsx` - Success page after payment
   - `PaymentCancel.jsx` - Cancellation page

4. **Add to Auth Context**
   - Track `subscriptionStatus` in user state
   - Fetch from `/api/subscription-status/:email` on login
   - Update UI based on subscription tier

5. **Add Paywall Components**
   - Show upgrade prompts for free tier limits
   - Display benefits of premium
   - Use messages from `/src/utils/paywall-messages.js`

### Example Frontend Implementation

**Load Stripe.js in index.html**:
```html
<script src="https://js.stripe.com/v3/"></script>
```

**Create Stripe instance in React**:
```javascript
import { loadStripe } from '@stripe/stripe-js';

const stripePromise = loadStripe('pk_live_51RaZdFBgA5bvPz6v...');
```

**Redirect to Checkout**:
```javascript
const handleUpgrade = async (priceId) => {
  const response = await fetch('/api/stripe-checkout', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      priceId,
      email: user.email,
      successUrl: window.location.origin + '/chat?premium=success',
      cancelUrl: window.location.origin + '/premium?cancelled=true'
    })
  });

  const { url } = await response.json();
  window.location.href = url;  // Redirect to Stripe Checkout
};
```

---

## 🗄️ DATABASE SCHEMA

Users table includes these Stripe-related columns:

```sql
stripe_customer_id VARCHAR(255)
stripe_subscription_id VARCHAR(255)
subscription_tier VARCHAR(50)      -- 'free' or 'premium'
subscription_status VARCHAR(50)     -- 'active', 'cancelled', 'past_due'
subscription_end_date DATETIME
last_payment_date DATETIME
last_payment_amount DECIMAL(10, 2)
```

Webhook handler automatically updates these fields when payment events occur.

---

## 🧪 TESTING

### Test Cards (Stripe Test Mode)
If you want to test in development, switch to test keys and use:

**Success**: `4242 4242 4242 4242`
**Decline**: `4000 0000 0000 0002`
**3D Secure**: `4000 0025 0000 3155`

Use any future expiration date and any CVC.

### Test Endpoints Locally
```bash
# Get Stripe config
curl http://localhost:3333/api/stripe-config

# Check subscription status
curl http://localhost:3333/api/subscription-status/user@example.com
```

### Test Endpoints Publicly
```bash
# Get Stripe config
curl https://justlay.me/api/stripe-config

# Check subscription status
curl https://justlay.me/api/subscription-status/please@justlay.me
```

---

## 🎁 PREMIUM FEATURES

### Free Tier Limits
- **LayMe v1 Characters**: 10 messages total
- **Custom Characters**: 5 messages per character
- **Character Creation**: 1 custom character maximum

### Premium Benefits (Unlimited)
- ✅ Unlimited messages with all characters
- ✅ Create unlimited custom characters
- ✅ Priority response times
- ✅ Extended conversation memory
- ✅ Advanced customization options
- ✅ Early access to new features
- ✅ Premium-only character templates
- ✅ Enhanced privacy features
- ✅ Black Mirror relationship analysis feature

---

## 📝 PAYWALL MESSAGES

Location: `/home/fastl/JustLayMe/src/utils/paywall-messages.js`

**Example Messages**:
- "Whoa there tiger! You've burned through your 10 free messages faster than I can say 'uncensored'. Ready to go unlimited?"
- "5 free messages with custom characters used up! Your creations are waiting for you in premium"
- "Whoa! Free users can only create 1 character. Upgrade to build your entire AI universe!"

Each paywall response includes:
```javascript
{
  error: 'Free tier limit reached',
  paywall: true,
  limit: 10,
  used: 10,
  message: "...",
  benefits: [...],
  upgradeUrl: '/api/stripe-checkout',
  upgradeText: "Upgrade to Premium"
}
```

---

## 🔧 SETUP FOR NEW STRIPE ACCOUNT (IF NEEDED)

If you need to create products/prices from scratch:

1. **Run Product Setup Script**:
```bash
cd /home/fastl/JustLayMe
node setup-stripe-products.js
```

2. **Update .env with new Price IDs**:
The script will output the price IDs to add to your `.env`

3. **Configure Webhook Endpoint**:
   - Go to Stripe Dashboard > Developers > Webhooks
   - Add endpoint: `https://justlay.me/api/webhooks/stripe`
   - Select events:
     - `customer.subscription.created`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
     - `invoice.payment_succeeded`
     - `invoice.payment_failed`
   - Copy webhook secret to `.env` as `STRIPE_WEBHOOK_SECRET`

---

## 📊 VERIFICATION CHECKLIST

- [x] Stripe SDK installed (`stripe@18.2.1`)
- [x] Environment variables configured
- [x] All payment endpoints active
- [x] Webhook handler implemented
- [x] CSP headers allow Stripe.js
- [x] Rate limiting configured
- [x] Database schema includes subscription fields
- [x] Paywall messages configured
- [x] Configuration validation active
- [ ] **TODO**: Frontend payment UI components
- [ ] **TODO**: Stripe Elements integration
- [ ] **TODO**: Premium page with pricing tiers
- [ ] **TODO**: Subscription status in Auth context

---

## 🚀 NEXT STEPS TO COMPLETE INTEGRATION

1. **Create PremiumPage Component** (`/home/fastl/JustLayMe/client/src/pages/PremiumPage.jsx`)
   - Display pricing tiers
   - Fetch prices from `/api/stripe-config`
   - Handle upgrade button clicks

2. **Add Stripe.js to Frontend** (`/home/fastl/JustLayMe/client/index.html`)
   - Add script tag for Stripe.js

3. **Create Payment Components**
   - CheckoutModal or redirect to Stripe Checkout
   - Success/Cancel pages

4. **Update Auth Context**
   - Add subscription status to user state
   - Fetch on login from `/api/subscription-status/:email`

5. **Add Paywall UI**
   - Show upgrade prompts when limits hit
   - Use messages from backend paywall-messages.js

---

## 📚 REFERENCE FILES

**Backend Files** (Already Migrated):
- `/home/fastl/JustLayMe/src/ai-server.js` - Payment endpoints (lines 1752-2545)
- `/home/fastl/JustLayMe/src/config/environment.js` - Config management
- `/home/fastl/JustLayMe/src/config-validator.js` - Validation
- `/home/fastl/JustLayMe/src/utils/paywall-messages.js` - Paywall messages
- `/home/fastl/JustLayMe/src/custom-characters-api.js` - Character limits
- `/home/fastl/JustLayMe/.env` - Stripe keys (SECURED)

**Scripts**:
- `/home/fastl/JustLayMe/setup-stripe-products.js` - Create products/prices

**Old Frontend Reference** (For Porting):
- `/home/fastl/JustLayMe-old-backend/public/assets/PremiumPage-CmX245sv.js` - Old premium page
- `/home/fastl/JustLayMe-old-backend/public/index.html` - Stripe.js integration example

---

## ✅ SYSTEM STATUS: BACKEND READY, FRONTEND TODO

**Backend**: 100% Complete ✅
- All endpoints working
- Webhook handler active
- Database schema ready
- Live keys configured

**Frontend**: Needs Implementation 🚧
- Premium page component needed
- Stripe Elements integration needed
- Auth context update needed
- Paywall UI components needed

**Estimated Frontend Work**: 3-4 hours for complete payment flow

---

**Last Updated**: November 17, 2025
**Migration Status**: Backend Complete, Frontend Pending
**Documentation**: Complete
