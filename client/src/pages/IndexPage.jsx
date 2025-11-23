import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Helmet } from 'react-helmet-async'
import { usePageTransition } from '@/hooks/usePageTransition'
import { useAuth } from '@/hooks/useAuth'
import { useModal } from '@/hooks/useModal'
import ProfileCard from '@/components/common/ProfileCard'
import ShinyText from '@/components/common/ShinyText'
import FallingText from '@/components/common/FallingText'
import RevealContainer from '@/components/common/RevealContainer'
import SpotlightCard from '@/components/common/SpotlightCard'
import LightRays from '@/components/common/LightRays'
import RotatingText from '@/components/common/RotatingText'
import Magnet from '@/components/common/Magnet'
import './IndexPage.scss'

export default function IndexPage() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const navigate = useNavigate()
  const { startTransition } = usePageTransition()
  const { user } = useAuth()
  const premiumModal = useModal('premium-paywall')

  const handleBlackMirrorClick = () => {
    // Everyone can navigate to The Grey Mirror page
    // Premium check happens when they try to upload
    // ARCHITECTURAL FIX: Navigate FIRST, then start transition (matches working pattern in ChatArea/Sidebar)
    navigate('/grey-mirror')
    startTransition('/grey-mirror')
  }

  const handleTryFree = () => {
    // Navigate directly to chat - users can try without signing up
    navigate('/chat')
    startTransition('/chat')
  }

  const handleSignUp = () => {
    // Navigate to login page in signup mode
    navigate('/login')
    startTransition('/login')
  }

  const handlePremium = () => {
    // Navigate to premium page
    navigate('/premium')
    startTransition('/premium')
  }

  const handleCTAClick = () => {
    // ARCHITECTURAL FIX: Navigate FIRST, then start transition (removes race condition)
    navigate('/chat')
    startTransition('/chat')
  }

  const handleSignIn = () => {
    // ARCHITECTURAL FIX: Navigate FIRST, then start transition (removes race condition)
    navigate('/login')
    startTransition('/login')
  }

  return (
    <div className="index-page">
      <Helmet>
        <title>JustLayMe - Unfiltered AI Conversations | Chat Without Restrictions</title>
        <meta name="description" content="Experience truly unfiltered AI conversations. Chat with advanced AI without restrictions, create custom characters, and analyze your relationships with The Grey Mirror." />
        <link rel="canonical" href="https://justlay.me/" />
        <meta property="og:title" content="JustLayMe - Unfiltered AI Conversations | Chat Without Restrictions" />
        <meta property="og:description" content="Experience truly unfiltered AI conversations. Chat with advanced AI without restrictions, create custom characters, and analyze your relationships with The Grey Mirror." />
        <meta property="og:url" content="https://justlay.me/" />
        <meta property="og:type" content="website" />
        <meta property="og:image" content="https://justlay.me/og-image.jpg" />
        <meta property="og:image:width" content="1200" />
        <meta property="og:image:height" content="630" />
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content="JustLayMe - Unfiltered AI Conversations | Chat Without Restrictions" />
        <meta name="twitter:description" content="Experience truly unfiltered AI conversations. Chat with advanced AI without restrictions, create custom characters, and analyze your relationships with The Grey Mirror." />
        <meta name="twitter:image" content="https://justlay.me/twitter-image.jpg" />
      </Helmet>

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
          <div className="navbar-brand" style={{ fontSize: '1.5rem', fontWeight: '600' }}>
            Justlay.
            <RotatingText
              texts={['Me', 'You', 'Her', 'Him', 'Yourself', 'Everyone', 'Someone', 'Back', 'Down', 'Low']}
              mainClassName="rotating-brand-highlight"
              splitBy="words"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.3 }}
              rotationInterval={2000}
            />
          </div>

          {/* Desktop Navigation */}
          <div className="navbar-links desktop">
            <a href="#features">Features</a>
            <a href="#pricing">Pricing</a>
            <a href="#about">About</a>
            <Magnet padding={80} magnetStrength={3}>
              <button className="btn-nav" onClick={handleSignIn}>Sign In</button>
            </Magnet>
          </div>

          {/* Mobile Navigation */}
          <div className="navbar-mobile">
            <Magnet padding={40} magnetStrength={2}>
              <button className="btn-nav mobile-signin" onClick={handleSignIn}>Sign In</button>
            </Magnet>
            <button
              className="mobile-menu-toggle"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label="Toggle menu"
            >
              <span className={`hamburger ${mobileMenuOpen ? 'active' : ''}`}>
                <span></span>
                <span></span>
                <span></span>
              </span>
            </button>
          </div>
        </div>

        {/* Mobile Menu Overlay */}
        {mobileMenuOpen && (
          <div className="mobile-menu-overlay">
            <div className="mobile-menu-content">
              <a href="#features" onClick={() => setMobileMenuOpen(false)}>Features</a>
              <a href="#pricing" onClick={() => setMobileMenuOpen(false)}>Pricing</a>
              <a href="#about" onClick={() => setMobileMenuOpen(false)}>About</a>
              <a href="/terms" onClick={() => setMobileMenuOpen(false)}>Terms</a>
              <a href="/privacy" onClick={() => setMobileMenuOpen(false)}>Privacy</a>
            </div>
          </div>
        )}
      </nav>

      {/* Main Content */}
      <main>
        {/* Hero Section */}
        <section className="hero">
        <div className="container hero-container">
          <div className="hero-left">
            <h1><ShinyText speed={5}>Unfiltered Conversations with AI</ShinyText></h1>
            <p className="hero-subtitle">
              <ShinyText speed={4}>No restrictions. No filters. Just real, authentic conversations with advanced AI.</ShinyText>
            </p>

            <div className="hero-cta-buttons">
              <Magnet padding={80} magnetStrength={3}>
                <button className="btn-primary btn-large" onClick={handleTryFree}>
                  Try Free - No Signup
                </button>
              </Magnet>
              <Magnet padding={80} magnetStrength={3}>
                <button className="btn-secondary btn-large" onClick={handleSignUp}>
                  Create Account
                </button>
              </Magnet>
            </div>
            <p className="hero-hint">Start chatting instantly, or sign up to save conversations</p>

            <div className="hero-stats">
              <div className="stat">
                <span className="stat-value">10K+</span>
                <span className="stat-label"><ShinyText speed={3} className="variant-subtle">Active Users</ShinyText></span>
              </div>
              <div className="stat">
                <span className="stat-value">4.8★</span>
                <span className="stat-label"><ShinyText speed={3} className="variant-subtle">Avg Rating</ShinyText></span>
              </div>
              <div className="stat">
                <span className="stat-value">24/7</span>
                <span className="stat-label"><ShinyText speed={3} className="variant-subtle">Available</ShinyText></span>
              </div>
            </div>
          </div>

          <div className="hero-right">
            <div
              className="black-mirror-card-wrapper"
              onClick={handleBlackMirrorClick}
              style={{ cursor: 'pointer' }}
            >
              <ProfileCard
                name="🪞 The Grey Mirror"
                title="Enter The Mirror"
                handle="justlayme"
                status="Revolutionary AI Analysis"
                showUserInfo={false}
                enableTilt={true}
                enableMobileTilt={true}
                behindGlowEnabled={true}
                behindGlowColor="rgba(6, 182, 212, 0.5)"
              >
                <FallingText
                  text="Upload conversations & memories. Watch as The Mirror reveals hidden patterns, exposes truths, and shows you exactly who you are"
                  highlightWords={['Mirror', 'reveals', 'patterns', 'truths']}
                  highlightClass="highlighted"
                  trigger="hover"
                  backgroundColor="transparent"
                  wireframes={false}
                  gravity={0.7}
                  mouseConstraintStiffness={0.7}
                  fontSize="0.8rem"
                />
              </ProfileCard>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="features" id="features">
        <div className="container">
          <RevealContainer variant="materialize" delay={0}>
            <div className="section-header">
              <h2>Why Users Love Justlay.Me</h2>
              <p><ShinyText speed={4}>Everything you need for meaningful AI conversations</ShinyText></p>
            </div>
          </RevealContainer>

          <div className="features-grid">
            <RevealContainer variant="quantum" delay={100}>
              <SpotlightCard className="feature variant-elevated">
                <h3>Advanced AI Models</h3>
                <p><ShinyText speed={3} className="variant-subtle">Powered by state-of-the-art language models that understand context, nuance, and deliver intelligent responses.</ShinyText></p>
              </SpotlightCard>
            </RevealContainer>

            <RevealContainer variant="quantum" delay={200}>
              <SpotlightCard className="feature variant-elevated">
                <h3>Custom AI Characters</h3>
                <p><ShinyText speed={3} className="variant-subtle">Create unique AI personas with distinct personalities, voices, and conversation styles tailored to your needs.</ShinyText></p>
              </SpotlightCard>
            </RevealContainer>

            <RevealContainer variant="quantum" delay={300}>
              <SpotlightCard className="feature variant-elevated">
                <h3>Conversation Memory</h3>
                <p><ShinyText speed={3} className="variant-subtle">Your conversations are saved with full context. AI remembers everything and picks up exactly where you left off.</ShinyText></p>
              </SpotlightCard>
            </RevealContainer>

            <RevealContainer variant="quantum" delay={100}>
              <SpotlightCard className="feature variant-elevated">
                <h3>Instant Responses</h3>
                <p><ShinyText speed={3} className="variant-subtle">Lightning-fast reply generation. Get responses in seconds, not minutes. Optimized for real-time interaction.</ShinyText></p>
              </SpotlightCard>
            </RevealContainer>

            <RevealContainer variant="quantum" delay={200}>
              <SpotlightCard className="feature variant-elevated">
                <h3>Private & Secure</h3>
                <p><ShinyText speed={3} className="variant-subtle">End-to-end encryption keeps your conversations completely private. Your data is yours alone.</ShinyText></p>
              </SpotlightCard>
            </RevealContainer>

            <RevealContainer variant="quantum" delay={300}>
              <SpotlightCard className="feature variant-elevated">
                <h3>Voice Cloning</h3>
                <p><ShinyText speed={3} className="variant-subtle">Clone your voice for natural speech interaction. Communicate with AI using your own voice and personality.</ShinyText></p>
              </SpotlightCard>
            </RevealContainer>
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section className="pricing" id="pricing">
        <div className="container">
          <RevealContainer variant="materialize" delay={0}>
            <div className="section-header">
              <h2>Simple, Transparent Pricing</h2>
              <p><ShinyText speed={4}>Choose the plan that fits your needs</ShinyText></p>
            </div>
          </RevealContainer>

          <div className="pricing-grid">
            <RevealContainer variant="slide-left" delay={100}>
              <SpotlightCard className="pricing-card">
                <h3>Free</h3>
                <div className="price">$0<span className="period">/month</span></div>
                <ul className="features-list">
                  <li><ShinyText speed={3} className="variant-subtle">Limited conversations</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">Basic AI models</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">1 character slot</ShinyText></li>
                  <li className="unavailable"><ShinyText speed={3} className="variant-subtle">Voice cloning</ShinyText></li>
                  <li className="unavailable"><ShinyText speed={3} className="variant-subtle">Priority support</ShinyText></li>
                </ul>
                <Magnet padding={80} magnetStrength={3}>
                  <button className="btn-secondary" onClick={handleTryFree}>Get Started Free</button>
                </Magnet>
              </SpotlightCard>
            </RevealContainer>

            <RevealContainer variant="materialize" delay={200}>
              <SpotlightCard className="pricing-card featured" spotlightColor="rgba(6, 182, 212, 0.3)">
                <div className="badge">Most Popular</div>
                <h3>Premium</h3>
                <div className="price">$9.99<span className="period">/month</span></div>
                <ul className="features-list">
                  <li><ShinyText speed={3} className="variant-subtle">Unlimited conversations</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">All AI models</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">Unlimited characters</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">Voice cloning</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">Priority support</ShinyText></li>
                </ul>
                <Magnet padding={80} magnetStrength={3}>
                  <button className="btn-primary" onClick={handlePremium}>Subscribe Now</button>
                </Magnet>
              </SpotlightCard>
            </RevealContainer>

            <RevealContainer variant="slide-right" delay={100}>
              <SpotlightCard className="pricing-card">
                <h3>Pro</h3>
                <div className="price">$19.99<span className="period">/month</span></div>
                <ul className="features-list">
                  <li><ShinyText speed={3} className="variant-subtle">Everything in Premium</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">API Access</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">Custom models</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">Advanced analytics</ShinyText></li>
                  <li><ShinyText speed={3} className="variant-subtle">Dedicated support</ShinyText></li>
                </ul>
                <Magnet padding={80} magnetStrength={3}>
                  <button className="btn-secondary" onClick={handlePremium}>Subscribe Now</button>
                </Magnet>
              </SpotlightCard>
            </RevealContainer>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="cta">
        <RevealContainer variant="emerge" delay={0}>
          <div className="container">
            <h2>Ready to experience unfiltered AI?</h2>
            <p><ShinyText speed={4}>Join thousands of users discovering the power of authentic conversations</ShinyText></p>
            <Magnet padding={100} magnetStrength={2.5}>
              <button className="btn-primary btn-large" onClick={handleCTAClick}>Start Free Today</button>
            </Magnet>
          </div>
        </RevealContainer>
      </section>
      </main>

      {/* Footer */}
      <footer className="footer">
        <div className="container">
          <div className="footer-grid">
            <div className="footer-col">
              <h4 style={{ fontSize: '1.5rem', fontWeight: '600' }}>
                Justlay.
                <RotatingText
                  texts={['Me', 'You', 'Her', 'Him', 'Yourself', 'Everyone', 'Someone', 'Back', 'Down', 'Low']}
                  mainClassName="rotating-brand-highlight"
                  splitBy="words"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.3 }}
                  rotationInterval={2000}
                />
              </h4>
              <p><ShinyText speed={3} className="variant-subtle">Unfiltered AI conversations</ShinyText></p>
            </div>
            <div className="footer-col">
              <h4>Product</h4>
              <ul>
                <li><a href="#features">Features</a></li>
                <li><a href="#pricing">Pricing</a></li>
                <li><a href="#about">About</a></li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Legal</h4>
              <ul>
                <li><a href="/terms">Terms</a></li>
                <li><a href="/privacy">Privacy</a></li>
                <li><a href="/contact">Contact</a></li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Connect</h4>
              <ul>
                <li><a href="#">Twitter</a></li>
                <li><a href="#">Discord</a></li>
                <li><a href="#">GitHub</a></li>
              </ul>
            </div>
          </div>
          <div className="footer-bottom">
            <p>&copy; 2024 Justlay.Me. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  )
}
