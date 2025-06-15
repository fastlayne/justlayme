// Payment Integration for JustLayMe Premium
// This integrates with Stripe for payment processing

// Initialize Stripe (you'll need to add your publishable key)
const STRIPE_PUBLISHABLE_KEY = 'pk_test_YOUR_KEY_HERE';
let stripe = null;

// Price IDs from Stripe Dashboard
const PRICE_IDS = {
    monthly: 'price_MONTHLY_ID',
    yearly: 'price_YEARLY_ID',
    lifetime: 'price_LIFETIME_ID'
};

// Initialize Stripe when the script loads
function initializeStripe() {
    if (typeof Stripe !== 'undefined') {
        stripe = Stripe(STRIPE_PUBLISHABLE_KEY);
    } else {
        console.error('Stripe.js not loaded. Add <script src="https://js.stripe.com/v3/"></script> to your HTML');
    }
}

// Create Stripe Checkout Session
async function createCheckoutSession(plan) {
    try {
        const response = await fetch('/api/create-checkout-session', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                priceId: PRICE_IDS[plan],
                plan: plan
            })
        });

        const session = await response.json();

        if (session.error) {
            throw new Error(session.error);
        }

        // Redirect to Stripe Checkout
        const result = await stripe.redirectToCheckout({
            sessionId: session.sessionId
        });

        if (result.error) {
            alert('Error: ' + result.error.message);
        }
    } catch (error) {
        console.error('Error creating checkout session:', error);
        alert('Payment system error. Please try again.');
    }
}

// Handle successful payment (call this from success page)
async function handlePaymentSuccess() {
    const urlParams = new URLSearchParams(window.location.search);
    const sessionId = urlParams.get('session_id');

    if (sessionId) {
        try {
            const response = await fetch('/api/verify-payment', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ sessionId })
            });

            const data = await response.json();

            if (data.success) {
                // Update user's premium status
                localStorage.setItem('isPremium', 'true');
                localStorage.setItem('subscriptionType', data.plan);
                localStorage.setItem('subscriptionEnd', data.endDate);

                // Redirect to main app
                window.location.href = '/';
            }
        } catch (error) {
            console.error('Error verifying payment:', error);
        }
    }
}

// Add Stripe payment endpoints to your Express server
function addStripeEndpoints(app) {
    const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

    // Create checkout session
    app.post('/api/create-checkout-session', async (req, res) => {
        try {
            const { priceId, plan } = req.body;

            const session = await stripe.checkout.sessions.create({
                payment_method_types: ['card'],
                line_items: [{
                    price: priceId,
                    quantity: 1,
                }],
                mode: plan === 'lifetime' ? 'payment' : 'subscription',
                success_url: `${process.env.DOMAIN}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
                cancel_url: `${process.env.DOMAIN}/`,
                metadata: {
                    plan: plan
                }
            });

            res.json({ sessionId: session.id });
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    });

    // Verify payment
    app.post('/api/verify-payment', async (req, res) => {
        try {
            const { sessionId } = req.body;
            const session = await stripe.checkout.sessions.retrieve(sessionId);

            if (session.payment_status === 'paid') {
                // Update user in database
                const plan = session.metadata.plan;
                let endDate = null;

                if (plan !== 'lifetime') {
                    const subscription = await stripe.subscriptions.retrieve(session.subscription);
                    endDate = new Date(subscription.current_period_end * 1000);
                }

                // Here you would update your database
                // For now, we'll just return the data
                res.json({
                    success: true,
                    plan: plan,
                    endDate: endDate
                });
            } else {
                res.status(400).json({ error: 'Payment not completed' });
            }
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    });

    // Webhook for subscription updates
    app.post('/api/stripe-webhook', express.raw({ type: 'application/json' }), async (req, res) => {
        const sig = req.headers['stripe-signature'];
        let event;

        try {
            event = stripe.webhooks.constructEvent(
                req.body,
                sig,
                process.env.STRIPE_WEBHOOK_SECRET
            );
        } catch (err) {
            return res.status(400).send(`Webhook Error: ${err.message}`);
        }

        // Handle the event
        switch (event.type) {
            case 'customer.subscription.updated':
            case 'customer.subscription.deleted':
                const subscription = event.data.object;
                // Update user's subscription status in database
                console.log('Subscription update:', subscription);
                break;
            default:
                console.log(`Unhandled event type ${event.type}`);
        }

        res.json({ received: true });
    });
}

// Alternative: PayPal Integration
const PAYPAL_CLIENT_ID = 'YOUR_PAYPAL_CLIENT_ID';

function initializePayPal() {
    // Add PayPal script to page
    const script = document.createElement('script');
    script.src = `https://www.paypal.com/sdk/js?client-id=${PAYPAL_CLIENT_ID}&currency=USD`;
    document.head.appendChild(script);

    script.onload = () => {
        paypal.Buttons({
            createOrder: function(data, actions) {
                const plan = selectedPlan;
                const amount = plan === 'monthly' ? '9.99' : 
                              plan === 'yearly' ? '79.99' : '199.00';

                return actions.order.create({
                    purchase_units: [{
                        amount: {
                            value: amount
                        },
                        description: `JustLayMe Premium - ${plan}`
                    }]
                });
            },
            onApprove: function(data, actions) {
                return actions.order.capture().then(function(details) {
                    // Payment successful
                    handlePayPalSuccess(details);
                });
            }
        }).render('#paypal-button-container');
    };
}

async function handlePayPalSuccess(details) {
    // Verify payment on server
    const response = await fetch('/api/verify-paypal', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            orderId: details.id,
            plan: selectedPlan
        })
    });

    const data = await response.json();
    if (data.success) {
        localStorage.setItem('isPremium', 'true');
        window.location.reload();
    }
}

// Export functions for use in HTML
window.stripePayment = {
    init: initializeStripe,
    checkout: createCheckoutSession
};

window.paypalPayment = {
    init: initializePayPal
};