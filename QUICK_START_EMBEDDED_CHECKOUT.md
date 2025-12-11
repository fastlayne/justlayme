# Quick Start - Stripe Embedded Checkout

## What Was Done

Converted Stripe checkout from **redirect-based** to **embedded modal** for a better user experience.

## Files Changed

### Frontend (COMPLETE)
- ✅ Installed `@stripe/stripe-js` and `@stripe/react-stripe-js`
- ✅ Created `StripeCheckoutModal.jsx` (embedded payment form)
- ✅ Created `StripeCheckoutModal.scss` (dark theme styles)
- ✅ Updated `PremiumPaywallModal.jsx` (show modal instead of redirect)
- ✅ Updated `stripeAPI.js` (added createPaymentIntent method)

### Backend (NEEDS IMPLEMENTATION)
- ❌ Need to create `POST /api/create-payment-intent` endpoint
- ❌ Need to update webhook handler for `payment_intent.succeeded`

## Backend: What You Need to Do

### 1. Create New Endpoint

File: Your backend API routes (e.g., `routes/stripe.js`)

```javascript
app.post('/api/create-payment-intent', async (req, res) => {
  try {
    const { priceId, email } = req.body;

    // Get price details from Stripe
    const price = await stripe.prices.retrieve(priceId);

    // Create Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: price.unit_amount,
      currency: price.currency,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        priceId: priceId,
        email: email,
      },
      receipt_email: email,
    });

    res.json({
      clientSecret: paymentIntent.client_secret
    });
  } catch (error) {
    console.error('Error creating payment intent:', error);
    res.status(500).json({ error: error.message });
  }
});
```

### 2. Update Webhook Handler

Add this event handler to your existing webhook endpoint:

```javascript
case 'payment_intent.succeeded': {
  const paymentIntent = event.data.object;
  const { email, priceId } = paymentIntent.metadata;

  // 1. Update user in database
  await db.users.update(
    { email },
    { isPremium: true, priceId, paidAt: new Date() }
  );

  // 2. Send confirmation email
  await sendPremiumConfirmationEmail(email);

  console.log('Premium access granted to:', email);
  break;
}
```

## Testing

### 1. Test Cards (Stripe Test Mode)

```
Success:  4242 4242 4242 4242
Decline:  4000 0000 0000 0002
3D Auth:  4000 0027 6000 3184
```

Use any future date, any CVC, any postal code.

### 2. Test Flow

1. Start your backend server
2. Start your frontend (`npm run dev`)
3. Navigate to a premium feature
4. Click upgrade on any plan
5. Embedded modal should appear
6. Enter test card details
7. Submit payment
8. Should redirect to `/chat?premium=success`

## Verify It's Working

### Frontend Checklist
- [ ] Stripe packages installed (`npm list @stripe/stripe-js`)
- [ ] Modal appears when clicking upgrade button
- [ ] Payment form loads inside modal
- [ ] No browser console errors

### Backend Checklist
- [ ] `/api/create-payment-intent` endpoint returns `clientSecret`
- [ ] Webhook receives `payment_intent.succeeded` event
- [ ] User's premium status updates in database
- [ ] Confirmation email sent

## Troubleshooting

### Modal doesn't appear
```bash
# Check if packages are installed
npm list @stripe/stripe-js @stripe/react-stripe-js

# Rebuild if needed
npm run build
```

### Payment Intent creation fails
- Check backend logs
- Verify Stripe secret key is correct
- Ensure price ID exists in Stripe Dashboard

### Payment succeeds but user not upgraded
- Check webhook endpoint is reachable
- Verify webhook secret in environment variables
- Check Stripe Dashboard > Webhooks for delivery logs

## Environment Variables

Make sure these are set in your backend `.env`:

```env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_MONTHLY=price_...
STRIPE_PRICE_YEARLY=price_...
STRIPE_PRICE_LIFETIME=price_...
```

## Production Deployment

### Before Going Live:

1. **Switch to Live Keys**
   ```env
   STRIPE_SECRET_KEY=sk_live_...
   STRIPE_PUBLISHABLE_KEY=pk_live_...
   ```

2. **Register Webhook in Stripe Dashboard**
   - Go to Stripe Dashboard > Developers > Webhooks
   - Add endpoint: `https://yourdomain.com/api/stripe-webhook`
   - Select events: `payment_intent.succeeded`, `payment_intent.payment_failed`
   - Copy webhook signing secret to `.env`

3. **Enable HTTPS**
   - Stripe requires HTTPS in production
   - Verify SSL certificate is valid

4. **Test with Real Card**
   - Use a real card in test mode first
   - Verify full flow before switching to live mode

## Support Resources

- **Implementation Guide**: `STRIPE_EMBEDDED_IMPLEMENTATION.md`
- **Backend Guide**: `STRIPE_EMBEDDED_BACKEND.md`
- **Flow Diagram**: `EMBEDDED_CHECKOUT_FLOW.md`
- **Stripe Docs**: https://stripe.com/docs/payments/payment-element
- **React Stripe Docs**: https://github.com/stripe/react-stripe-js

## Quick Commands

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Check Stripe package versions
npm list @stripe/stripe-js @stripe/react-stripe-js
```

## Visual Confirmation

When working correctly, you should see:

1. User clicks "Subscribe Monthly" (or Yearly/Lifetime)
2. **Dark modal appears ON TOP** of the pricing modal
3. Payment form loads with "Complete Your Purchase" header
4. Stripe Payment Element shows card input fields
5. User can enter card details without leaving your site
6. After payment, redirects to success page

## Current Status

| Component | Status |
|-----------|--------|
| Frontend Package Installation | ✅ Complete |
| Embedded Checkout Component | ✅ Complete |
| Premium Paywall Update | ✅ Complete |
| Styling (Dark Theme) | ✅ Complete |
| Backend API Endpoint | ⏳ Needs Implementation |
| Webhook Handler | ⏳ Needs Implementation |

**Next Step**: Implement backend endpoint (30-60 minutes)

## Need Help?

Check the detailed documentation:
- For complete implementation details: `STRIPE_EMBEDDED_IMPLEMENTATION.md`
- For backend code examples: `STRIPE_EMBEDDED_BACKEND.md`
- For visual flow: `EMBEDDED_CHECKOUT_FLOW.md`
