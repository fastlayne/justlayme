# Stripe Embedded Checkout - Backend Implementation Guide

This document explains the backend changes needed to support the new embedded Stripe checkout flow.

## Overview

The frontend has been updated to use **Stripe's embedded checkout** using Payment Elements instead of redirecting to Stripe's hosted checkout page. This provides a better user experience with the payment form appearing as a modal overlay on the site.

## Required Backend Changes

### 1. New API Endpoint: `POST /api/create-payment-intent`

You need to add a new endpoint that creates a Payment Intent instead of a Checkout Session.

#### Request Body:
```json
{
  "priceId": "price_xxxxx",  // Stripe Price ID (monthly/yearly/lifetime)
  "email": "user@example.com"
}
```

#### Response:
```json
{
  "clientSecret": "pi_xxxxx_secret_xxxxx"  // Payment Intent client secret
}
```

#### Implementation Example (Node.js/Express):

```javascript
app.post('/api/create-payment-intent', async (req, res) => {
  try {
    const { priceId, email } = req.body;

    // Get the price from Stripe to determine amount
    const price = await stripe.prices.retrieve(priceId);

    // Create a Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: price.unit_amount,
      currency: price.currency,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        priceId: priceId,
        email: email,
        // Add any other metadata you need for your business logic
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

### 2. Webhook Handler Updates

You'll need to handle these Stripe webhook events for embedded checkout:

#### Key Events to Handle:

1. **`payment_intent.succeeded`** - Payment completed successfully
   - Create/update user subscription in your database
   - Grant premium access to the user
   - Send confirmation email

2. **`payment_intent.payment_failed`** - Payment failed
   - Log the failure
   - Optionally notify the user

#### Example Webhook Handler:

```javascript
app.post('/api/stripe-webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  switch (event.type) {
    case 'payment_intent.succeeded': {
      const paymentIntent = event.data.object;

      // Extract metadata
      const { email, priceId } = paymentIntent.metadata;

      // Update user's premium status in database
      await updateUserPremiumStatus(email, priceId);

      // Send confirmation email
      await sendPremiumConfirmationEmail(email);

      break;
    }

    case 'payment_intent.payment_failed': {
      const paymentIntent = event.data.object;
      console.error('Payment failed:', paymentIntent.id);
      break;
    }

    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  res.json({ received: true });
});
```

### 3. Keep Existing Endpoints (Optional)

The existing endpoints can remain for backward compatibility:
- `GET /api/stripe-config` - Returns publishable key and prices (ALREADY USED)
- `POST /api/stripe-checkout` - Creates hosted checkout session (LEGACY, not used anymore)

### 4. Update `/api/stripe-config` Response

Make sure this endpoint returns the publishable key:

```javascript
app.get('/api/stripe-config', async (req, res) => {
  try {
    const prices = {
      monthly: {
        id: process.env.STRIPE_PRICE_MONTHLY,
        amount: 999  // $9.99 in cents
      },
      yearly: {
        id: process.env.STRIPE_PRICE_YEARLY,
        amount: 7500  // $75.00 in cents
      },
      lifetime: {
        id: process.env.STRIPE_PRICE_LIFETIME,
        amount: 15000  // $150.00 in cents
      }
    };

    res.json({
      publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
      prices: prices
    });
  } catch (error) {
    console.error('Error fetching Stripe config:', error);
    res.status(500).json({ error: error.message });
  }
});
```

## Environment Variables Needed

```env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_MONTHLY=price_...
STRIPE_PRICE_YEARLY=price_...
STRIPE_PRICE_LIFETIME=price_...
```

## Testing

### Test with Stripe Test Cards:

1. **Success**: `4242 4242 4242 4242`
2. **Decline**: `4000 0000 0000 0002`
3. **3D Secure**: `4000 0027 6000 3184`

Use any future expiry date, any CVC, and any postal code.

## Key Differences from Checkout Session

| Aspect | Checkout Session (Old) | Payment Intent (New) |
|--------|----------------------|---------------------|
| User Flow | Redirects to Stripe | Stays on site |
| Implementation | Simple redirect | Elements integration |
| Customization | Limited | Full control |
| Stripe Link | Auto-enabled | Auto-enabled |
| Payment Methods | All enabled | All enabled |

## Frontend Integration

The frontend now:
1. Loads `@stripe/stripe-js` and `@stripe/react-stripe-js`
2. Creates a Payment Intent via `/api/create-payment-intent`
3. Displays Stripe's Payment Element in a modal
4. Handles payment confirmation client-side
5. Redirects to success page after payment

## Security Notes

- Payment Intent secrets are one-time use only
- Always validate webhook signatures
- Store metadata in Payment Intent for business logic
- Never trust client-side payment status - always verify via webhooks

## Support for Subscriptions vs One-Time Payments

Currently, all three plans (Monthly, Yearly, Lifetime) are configured as **one-time payments** using Payment Intents.

If you want Monthly/Yearly to be **recurring subscriptions**, you'll need to:
1. Use Subscription objects instead of Payment Intents for those plans
2. Handle `customer.subscription.created` and `customer.subscription.updated` webhooks
3. Update the frontend to handle subscriptions differently

## Questions?

If you need help implementing this on the backend, refer to:
- [Stripe Payment Intents API](https://stripe.com/docs/api/payment_intents)
- [Stripe Payment Element](https://stripe.com/docs/payments/payment-element)
- [Stripe Webhooks](https://stripe.com/docs/webhooks)
