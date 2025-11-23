import { useState, useEffect } from 'react'
import { Helmet } from 'react-helmet-async'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '@/hooks/useAuth'
import { usePageTransition } from '@/hooks/usePageTransition'
import { stripeAPI } from '@/services/stripeAPI'
import Magnet from '@/components/common/Magnet'
import ShinyText from '@/components/common/ShinyText'
import RevealContainer from '@/components/common/RevealContainer'
import SpotlightCard from '@/components/common/SpotlightCard'
import LightRays from '@/components/common/LightRays'
import RotatingText from '@/components/common/RotatingText'
import PremiumPaywallModal from '@/components/modals/PremiumPaywallModal'
import './PremiumPage.scss'

/**
 * PremiumPage Component
 * Dedicated premium/pricing page with feature comparison and CTAs
 * Uses react-helmet-async for SEO
 * Integrates with PremiumPaywallModal for upgrade flow
 */

export default function PremiumPage() {
  const { user, isPremium } = useAuth()
  const navigate = useNavigate()
  const { startTransition } = usePageTransition()
  const [showPaywall, setShowPaywall] = useState(false)
  const [selectedFeature, setSelectedFeature] = useState('unlimited conversations')
  const [billingPeriod, setBillingPeriod] = useState('monthly')

  const handleUpgrade = (feature) => {
    if (!user) {
      startTransition('/login')
      setTimeout(() => navigate('/login'), 100)
      return
    }
    setSelectedFeature(feature)
    setShowPaywall(true)
  }

  const handleCTAClick = () => {
    startTransition('/chat')
    setTimeout(() => navigate('/chat'), 100)
  }

  // Feature comparison matrix
  const features = [
    {
      name: 'Conversations',
      free: 'Limited (5/day)',
      premium: 'Unlimited',
      pro: 'Unlimited'
    },
    {
      name: 'AI Models',
      free: 'Basic models only',
      premium: 'All models included',
      pro: 'All models + custom'
    },
    {
      name: 'Character Slots',
      free: '1 character',
      premium: 'Unlimited',
      pro: 'Unlimited'
    },
    {
      name: 'Voice Cloning',
      free: false,
      premium: true,
      pro: true
    },
    {
      name: 'Voice Interaction',
      free: false,
      premium: true,
      pro: true
    },
    {
      name: 'The Grey Mirror Analysis',
      free: false,
      premium: true,
      pro: true
    },
    {
      name: 'Priority Support',
      free: false,
      premium: true,
      pro: true
    },
    {
      name: 'API Access',
      free: false,
      premium: false,
      pro: true
    },
    {
      name: 'Custom Models',
      free: false,
      premium: false,
      pro: true
    },
    {
      name: 'Advanced Analytics',
      free: false,
      premium: false,
      pro: true
    },
    {
      name: 'Dedicated Support',
      free: false,
      premium: false,
      pro: true
    }
  ]

  return (
    <>
      <Helmet>
        <title>Premium Plans - JustLayMe</title>
        <meta name="description" content="Unlock unlimited AI conversations with premium features. Choose from flexible monthly, yearly, or lifetime plans." />
        <meta property="og:title" content="Premium Plans - JustLayMe" />
        <meta property="og:description" content="Unlock unlimited AI conversations with premium features. Choose from flexible monthly, yearly, or lifetime plans." />
        <meta property="og:type" content="website" />
        <meta property="og:image" content="https://justlay.me/og-image.jpg" />
        <meta property="og:image:width" content="1200" />
        <meta property="og:image:height" content="630" />
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:image" content="https://justlay.me/twitter-image.jpg" />
      </Helmet>

      <div className="premium-page">
        {/* LightRays Background */}
        <LightRays
          raysOrigin="bottom-center"
          raysSpeed={0.4}
          lightSpread={0.2}
          rayLength={1.3}
          fadeDistance={1.2}
          saturation={0.9}
          mouseInfluence={0.4}
          noiseAmount={0}
          distortion={0}
          pulsating={true}
        />

        {/* Navigation */}
        <nav className="navbar">
          <div className="container">
            <button className="navbar-back" onClick={() => navigate('/')}>
              ← Back
            </button>
            <div className="navbar-brand" style={{ fontSize: '1.5rem', fontWeight: '600' }}>
              Justlay.
              <RotatingText
                texts={['Me', 'You', 'Premium']}
                mainClassName="rotating-brand-highlight"
                splitBy="words"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.3 }}
                rotationInterval={3000}
              />
            </div>
            <div style={{ width: '60px' }} /> {/* Spacer for alignment */}
          </div>
        </nav>

        {/* Main Content */}
        <main className="premium-content">
          {/* Header Section */}
          <section className="premium-header">
            <div className="container">
              <RevealContainer variant="materialize" delay={0}>
                <div className="header-content">
                  <h1>
                    <ShinyText speed={5}>Choose Your Plan</ShinyText>
                  </h1>
                  <p className="header-subtitle">
                    <ShinyText speed={4}>Unlock unlimited conversations and premium features</ShinyText>
                  </p>
                </div>
              </RevealContainer>

              {isPremium && (
                <RevealContainer variant="emerge" delay={100}>
                  <div className="premium-badge">
                    ✓ You're already a premium member!
                  </div>
                </RevealContainer>
              )}
            </div>
          </section>

          {/* Pricing Cards Section */}
          <section className="pricing-section">
            <div className="container">
              <div className="pricing-grid">
                {/* Free Plan */}
                <RevealContainer variant="slide-left" delay={100}>
                  <SpotlightCard className="pricing-card free">
                    <div className="card-header">
                      <h3>Free</h3>
                      <p className="plan-description">Perfect for trying out</p>
                    </div>

                    <div className="price-section">
                      <div className="price">
                        <span className="amount">$0</span>
                        <span className="period">/month</span>
                      </div>
                    </div>

                    <ul className="features-list">
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">5 conversations daily</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">Basic AI models</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">1 character slot</span>
                      </li>
                      <li className="feature-item unavailable">
                        <span className="feature-icon">✗</span>
                        <span className="feature-text">Voice features</span>
                      </li>
                      <li className="feature-item unavailable">
                        <span className="feature-icon">✗</span>
                        <span className="feature-text">Priority support</span>
                      </li>
                    </ul>

                    <Magnet padding={80} magnetStrength={3}>
                      <button className="btn-secondary btn-plan" disabled={!user}>
                        {user ? 'You\'re Using Free' : 'Sign Up Free'}
                      </button>
                    </Magnet>
                  </SpotlightCard>
                </RevealContainer>

                {/* Premium Plan */}
                <RevealContainer variant="materialize" delay={200}>
                  <SpotlightCard className="pricing-card premium featured" spotlightColor="rgba(6, 182, 212, 0.3)">
                    <div className="featured-badge">Most Popular</div>

                    <div className="card-header">
                      <h3>Premium</h3>
                      <p className="plan-description">For casual users</p>
                    </div>

                    <div className="price-section">
                      <div className="price">
                        <span className="amount">$9.99</span>
                        <span className="period">/month</span>
                      </div>
                      <p className="price-note">or $79.99/year (save 33%)</p>
                    </div>

                    <ul className="features-list">
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">Unlimited conversations</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">All AI models</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">Unlimited characters</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">Voice cloning & interaction</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">The Grey Mirror analysis</span>
                      </li>
                    </ul>

                    <Magnet padding={80} magnetStrength={3}>
                      <button
                        className={`btn-primary btn-plan ${isPremium ? 'disabled' : ''}`}
                        onClick={() => handleUpgrade('unlimited conversations')}
                        disabled={isPremium}
                      >
                        {isPremium ? 'Current Plan' : 'Start Free Trial'}
                      </button>
                    </Magnet>
                  </SpotlightCard>
                </RevealContainer>

                {/* Pro Plan */}
                <RevealContainer variant="slide-right" delay={100}>
                  <SpotlightCard className="pricing-card pro">
                    <div className="card-header">
                      <h3>Pro</h3>
                      <p className="plan-description">For power users</p>
                    </div>

                    <div className="price-section">
                      <div className="price">
                        <span className="amount">$19.99</span>
                        <span className="period">/month</span>
                      </div>
                      <p className="price-note">or $199.99 lifetime</p>
                    </div>

                    <ul className="features-list">
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">Everything in Premium</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">API access</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">Custom AI models</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">Advanced analytics</span>
                      </li>
                      <li className="feature-item">
                        <span className="feature-icon">✓</span>
                        <span className="feature-text">Dedicated support</span>
                      </li>
                    </ul>

                    <Magnet padding={80} magnetStrength={3}>
                      <button
                        className={`btn-secondary btn-plan ${isPremium ? 'disabled' : ''}`}
                        onClick={() => handleUpgrade('API access')}
                        disabled={isPremium}
                      >
                        {isPremium ? 'Upgrade Available' : 'Contact Sales'}
                      </button>
                    </Magnet>
                  </SpotlightCard>
                </RevealContainer>
              </div>
            </div>
          </section>

          {/* Feature Comparison Table */}
          <section className="comparison-section">
            <div className="container">
              <RevealContainer variant="materialize" delay={0}>
                <div className="section-header">
                  <h2>Detailed Feature Comparison</h2>
                  <p><ShinyText speed={4}>See exactly what you get with each plan</ShinyText></p>
                </div>
              </RevealContainer>

              <RevealContainer variant="emerge" delay={200}>
                <div className="comparison-table-wrapper">
                  <table className="comparison-table" role="table">
                    <thead>
                      <tr>
                        <th scope="col">Feature</th>
                        <th scope="col">Free</th>
                        <th scope="col">Premium</th>
                        <th scope="col">Pro</th>
                      </tr>
                    </thead>
                    <tbody>
                      {features.map((feature, index) => (
                        <tr key={index} className={index % 2 === 0 ? 'alt' : ''}>
                          <td className="feature-name">{feature.name}</td>
                          <td className="feature-value">
                            {typeof feature.free === 'boolean' ? (
                              <span className={feature.free ? 'checkmark' : 'cross'}>
                                {feature.free ? '✓' : '✗'}
                              </span>
                            ) : (
                              feature.free
                            )}
                          </td>
                          <td className="feature-value">
                            {typeof feature.premium === 'boolean' ? (
                              <span className={feature.premium ? 'checkmark' : 'cross'}>
                                {feature.premium ? '✓' : '✗'}
                              </span>
                            ) : (
                              feature.premium
                            )}
                          </td>
                          <td className="feature-value">
                            {typeof feature.pro === 'boolean' ? (
                              <span className={feature.pro ? 'checkmark' : 'cross'}>
                                {feature.pro ? '✓' : '✗'}
                              </span>
                            ) : (
                              feature.pro
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </RevealContainer>
            </div>
          </section>

          {/* FAQ Section */}
          <section className="faq-section">
            <div className="container">
              <RevealContainer variant="materialize" delay={0}>
                <div className="section-header">
                  <h2>Frequently Asked Questions</h2>
                </div>
              </RevealContainer>

              <div className="faq-grid">
                <RevealContainer variant="slide-left" delay={100}>
                  <div className="faq-item">
                    <h4>Can I cancel anytime?</h4>
                    <p>Yes! You can cancel your subscription at any time. No hidden fees or long-term contracts.</p>
                  </div>
                </RevealContainer>

                <RevealContainer variant="slide-right" delay={100}>
                  <div className="faq-item">
                    <h4>Is there a free trial?</h4>
                    <p>Premium subscribers get a 7-day free trial. Start exploring premium features immediately.</p>
                  </div>
                </RevealContainer>

                <RevealContainer variant="slide-left" delay={200}>
                  <div className="faq-item">
                    <h4>What payment methods do you accept?</h4>
                    <p>We accept all major credit cards and digital payment methods through Stripe.</p>
                  </div>
                </RevealContainer>

                <RevealContainer variant="slide-right" delay={200}>
                  <div className="faq-item">
                    <h4>Do you offer refunds?</h4>
                    <p>Yes, we offer a 30-day money-back guarantee on all subscriptions.</p>
                  </div>
                </RevealContainer>
              </div>
            </div>
          </section>

          {/* CTA Section */}
          <section className="cta-section">
            <RevealContainer variant="emerge" delay={0}>
              <div className="container">
                <h2>Ready to unlock premium features?</h2>
                <p><ShinyText speed={4}>Join thousands of users with unlimited conversations</ShinyText></p>
                <Magnet padding={100} magnetStrength={2.5}>
                  <button className="btn-primary btn-large" onClick={() => handleUpgrade('unlimited conversations')}>
                    {user ? 'Get Premium Now' : 'Sign Up & Get Premium'}
                  </button>
                </Magnet>
              </div>
            </RevealContainer>
          </section>
        </main>

        {/* Premium Paywall Modal */}
        {showPaywall && (
          <PremiumPaywallModal
            modalId="premium-page-paywall"
            onClose={() => setShowPaywall(false)}
            feature={selectedFeature}
          />
        )}
      </div>
    </>
  )
}
