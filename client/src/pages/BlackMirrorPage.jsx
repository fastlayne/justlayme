import { useState, useRef, useEffect, useContext } from 'react'
import { useNavigate } from 'react-router-dom'
import { Helmet } from 'react-helmet-async'
import { Upload } from 'lucide-react'
import { useAuth } from '@/hooks/useAuth'
import { useModal } from '@/hooks/useModal'
import { BlackMirrorContext } from '@/contexts/BlackMirrorContext'
import { runCompleteAnalysis } from '@/services/ml/mlOrchestrator'
import ShinyText from '@/components/common/ShinyText'
import ResultsSection from '@/components/blackmirror/ResultsSection'
import './BlackMirrorPage.scss'

/**
 * BlackMirrorPage Component
 * THE EYE THAT SEES ALL - Neural Surveillance Interface
 * Upload your consciousness for analysis
 */

export default function BlackMirrorPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const premiumModal = useModal('premium-paywall')
  const [isDragging, setIsDragging] = useState(false)
  const [files, setFiles] = useState([])
  const canvasRef = useRef(null)
  const [mousePos, setMousePos] = useState({ x: 0.5, y: 0.5 })
  const [showResults, setShowResults] = useState(false)

  // PERSONALIZATION: User and contact names + insights goal
  const [userName, setUserName] = useState('')
  const [contactName, setContactName] = useState('')
  const [insightsGoal, setInsightsGoal] = useState('')

  // Build personalization data object
  const getPersonalizationData = () => ({
    userName: userName.trim() || 'You',
    contactName: contactName.trim() || 'Them',
    insightsGoal: insightsGoal.trim() || '',
  })

  // FIX 4: Server-side premium verification instead of JWT-only check
  const [isPremium, setIsPremium] = useState(user?.isPremium === true)
  const [premiumCheckTime, setPremiumCheckTime] = useState(Date.now())

  // Get BlackMirror context for state management
  const {
    isAnalyzing,
    analysisId,
    mlReport,
    error,
    setAnalyzing,
    setAnalysisId,
    setMLReport,
    setError,
    clearError,
  } = useContext(BlackMirrorContext)

  // FIX 4: Verify premium status periodically from server
  useEffect(() => {
    if (!user?.id) return

    const verifyPremium = async () => {
      try {
        const response = await fetch(`/api/verify-premium/${user.id}`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('authToken')}`
          }
        })
        if (response.ok) {
          const data = await response.json()
          setIsPremium(data.isPremium)
        }
      } catch (error) {
        console.error('Failed to verify premium status:', error)
      }
    }

    // Check immediately and then every 5 minutes
    verifyPremium()
    const interval = setInterval(verifyPremium, 5 * 60 * 1000)
    return () => clearInterval(interval)
  }, [user?.id])

  // Mouse tracking for eye movement
  useEffect(() => {
    const handleMouseMove = (e) => {
      setMousePos({
        x: e.clientX / window.innerWidth,
        y: e.clientY / window.innerHeight
      })
    }
    window.addEventListener('mousemove', handleMouseMove)
    return () => window.removeEventListener('mousemove', handleMouseMove)
  }, [])

  // CRT scanline effect
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    let animationId
    let time = 0

    canvas.width = canvas.offsetWidth
    canvas.height = canvas.offsetHeight

    const animate = () => {
      ctx.fillStyle = '#000000'
      ctx.fillRect(0, 0, canvas.width, canvas.height)

      for (let i = 0; i < canvas.height; i += 4) {
        ctx.fillStyle = 'rgba(20, 40, 60, 0.08)'
        ctx.fillRect(0, i, canvas.width, 2)
      }

      time++
      animationId = requestAnimationFrame(animate)
    }

    animate()
    return () => cancelAnimationFrame(animationId)
  }, [])

  // Don't auto-start - user clicks button to analyze

  // Show results when analysis completes
  useEffect(() => {
    if (mlReport && !isAnalyzing) {
      setShowResults(true)
    }
  }, [mlReport, isAnalyzing])

  const handleDragOver = (e) => {
    e.preventDefault()
    setIsDragging(true)
  }

  const handleDragLeave = () => {
    setIsDragging(false)
  }

  const handleDrop = (e) => {
    e.preventDefault()
    setIsDragging(false)

    // Check for premium access before accepting files
    if (!isPremium) {
      premiumModal.openModal({
        feature: 'The Grey Mirror Analysis',
        description: 'Upload your consciousness and reveal the truth about your relationships'
      })
      return
    }

    // CRITICAL FIX: Validate file sizes before processing
    const MAX_FILE_SIZE = 50 * 1024 * 1024 // 50MB
    const droppedFiles = Array.from(e.dataTransfer.files)

    for (const file of droppedFiles) {
      if (file.size > MAX_FILE_SIZE) {
        setError(`File "${file.name}" exceeds 50MB limit (${(file.size / 1024 / 1024).toFixed(1)}MB)`)
        return
      }
    }

    // ARCHITECTURAL FIX: Replace files instead of appending
    // This ensures the most recently uploaded file is analyzed, not the first
    setFiles(droppedFiles)
    // Clear any previous results when new file is uploaded
    setShowResults(false)
    setMLReport(null)
  }

  const handleFileInput = (e) => {
    // Check for premium access before accepting files
    if (!isPremium) {
      e.preventDefault()
      e.target.value = '' // Reset the input
      premiumModal.openModal({
        feature: 'The Grey Mirror Analysis',
        description: 'Upload your consciousness and reveal the truth about your relationships'
      })
      return
    }

    // CRITICAL FIX: Validate file sizes before processing
    const MAX_FILE_SIZE = 50 * 1024 * 1024 // 50MB
    const selectedFiles = Array.from(e.target.files || [])

    for (const file of selectedFiles) {
      if (file.size > MAX_FILE_SIZE) {
        setError(`File "${file.name}" exceeds 50MB limit (${(file.size / 1024 / 1024).toFixed(1)}MB)`)
        e.target.value = ''
        return
      }
    }

    // ARCHITECTURAL FIX: Replace files instead of appending
    // This ensures the most recently uploaded file is analyzed, not the first
    setFiles(selectedFiles)
    // Clear any previous results when new file is uploaded
    setShowResults(false)
    setMLReport(null)
    e.target.value = ''
  }

  // Handle analysis start - integrate ML orchestrator
  const handleAnalysisStart = async () => {
    if (files.length === 0) {
      console.warn('❌ No files to analyze')
      return
    }

    try {
      console.log('🔮 Starting analysis...')
      setAnalyzing(true)
      clearError() // Clear any previous errors
      const analysisId = `analysis_${Date.now()}`
      setAnalysisId(analysisId)
      console.log('📝 Analysis ID:', analysisId)

      // CRITICAL FIX: Final file size check before reading
      const MAX_FILE_SIZE = 50 * 1024 * 1024 // 50MB
      const file = files[0]
      if (file.size > MAX_FILE_SIZE) {
        throw new Error(`File exceeds 50MB limit (${(file.size / 1024 / 1024).toFixed(1)}MB). Please upload a smaller file.`)
      }

      // Read file content
      console.log('📂 Reading file:', file.name)
      const fileContent = await file.text()
      console.log('✅ File read successfully, content length:', fileContent.length)

      // Run the ML analysis pipeline with personalization data
      console.log('🔄 Running ML analysis pipeline...')
      const personalization = getPersonalizationData()
      console.log('👤 Personalization:', personalization)
      const report = await runCompleteAnalysis(fileContent, 'file', personalization)
      console.log('📊 Analysis complete:', report)

      if (report.success) {
        console.log('✅ Analysis successful, setting report')
        setMLReport(report)
      } else {
        const errorMsg = report.error || 'Analysis failed'
        console.error('❌ Analysis failed:', errorMsg)
        console.error('📊 Report details:', report)
        setError(errorMsg)
      }
    } catch (err) {
      console.error('❌ Error during analysis:', err)
      console.error('📋 Error stack:', err.stack)
      setError(err.message || 'An unexpected error occurred during analysis')
    } finally {
      setAnalyzing(false)
    }
  }

  // Handle back to chat
  const handleBackToChat = () => {
    // ARCHITECTURAL FIX: Simple direct navigation
    // TransitionWrapper automatically detects route change and handles animation
    navigate('/chat')
  }

  const handleRestart = () => {
    setFiles([])
    setShowResults(false)
    setMLReport(null)
  }

  // Eye animation calculations
  const pupilOffset = {
    x: (mousePos.x - 0.5) * 90,
    y: (mousePos.y - 0.5) * 90
  }

  const cursorDistance = Math.sqrt(
    Math.pow(mousePos.x - 0.5, 2) + Math.pow(mousePos.y - 0.5, 2)
  )

  const maxInnerOffset = 35
  const innerPupilOffset = {
    x: (mousePos.x - 0.5) * maxInnerOffset * 2,
    y: (mousePos.y - 0.5) * maxInnerOffset * 2
  }

  const pupilSize = 20 + (1 - Math.min(cursorDistance, 1)) * 12
  const glowIntensity = 0.15 + Math.max(Math.abs(mousePos.x - 0.5), Math.abs(mousePos.y - 0.5)) * 0.3

  return (
    <>
      <Helmet>
        <title>The Grey Mirror - Neural Surveillance | JustLayMe</title>
        <meta name="description" content="Upload your consciousness for deep neural analysis. The eye sees all." />
        <link rel="canonical" href="https://justlay.me/grey-mirror" />
        <meta property="og:title" content="The Grey Mirror - Neural Surveillance | JustLayMe" />
        <meta property="og:description" content="Upload your consciousness for deep neural analysis. The eye sees all." />
        <meta property="og:url" content="https://justlay.me/grey-mirror" />
        <meta property="og:type" content="website" />
        <meta property="og:image" content="https://justlay.me/og-image.jpg" />
        <meta property="og:image:width" content="1200" />
        <meta property="og:image:height" content="630" />
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content="The Grey Mirror - Neural Surveillance | JustLayMe" />
        <meta name="twitter:description" content="Upload your consciousness for deep neural analysis. The eye sees all." />
        <meta name="twitter:image" content="https://justlay.me/twitter-image.jpg" />
      </Helmet>

      <div className="blackmirror-page-eye">
        <canvas ref={canvasRef} className="scanline-canvas" />

        {showResults && mlReport ? (
          <div className="results-container">
            <ResultsSection
              results={mlReport}
              expandedMetrics={{}}
              onRestart={handleRestart}
              personalization={getPersonalizationData()}
            />
            <button className="btn-back-eye" onClick={handleBackToChat}>
              ← Back to Chat
            </button>
          </div>
        ) : (
          <div className="eye-interface">
            {/* Title */}
            <div className="eye-title">
              <h1 className="title-text">
                <ShinyText speed={5}>THE GREY MIRROR</ShinyText>
              </h1>
              <div className="title-divider" />
            </div>

            {/* PERSONALIZATION FIELDS */}
            <div className="personalization-fields">
              <div className="name-fields">
                <div className="field-group">
                  <label htmlFor="userName">
                    <ShinyText speed={5}>Your Name</ShinyText>
                  </label>
                  <input
                    type="text"
                    id="userName"
                    placeholder="Enter your name..."
                    value={userName}
                    onChange={(e) => setUserName(e.target.value)}
                    disabled={isAnalyzing}
                    className="personalization-input"
                  />
                </div>
                <div className="field-group">
                  <label htmlFor="contactName">
                    <ShinyText speed={5}>Their Name</ShinyText>
                  </label>
                  <input
                    type="text"
                    id="contactName"
                    placeholder="Who are you messaging..."
                    value={contactName}
                    onChange={(e) => setContactName(e.target.value)}
                    disabled={isAnalyzing}
                    className="personalization-input"
                  />
                </div>
              </div>
              <div className="field-group insights-field">
                <label htmlFor="insightsGoal">
                  <ShinyText speed={5}>What insights are you looking for?</ShinyText>
                </label>
                <textarea
                  id="insightsGoal"
                  placeholder="e.g., 'Are they actually interested in me?', 'Is this relationship healthy?', 'Why do we keep arguing?'"
                  value={insightsGoal}
                  onChange={(e) => setInsightsGoal(e.target.value)}
                  disabled={isAnalyzing}
                  className="insights-textarea"
                  rows={2}
                />
              </div>
            </div>

            {/* Error Display */}
            {error && (
              <div className="error-container" style={{
                marginBottom: '2rem',
                padding: '1rem',
                backgroundColor: 'rgba(220, 38, 38, 0.1)',
                border: '1px solid rgba(220, 38, 38, 0.5)',
                borderRadius: '8px',
                color: '#fca5a5',
                fontSize: '0.95rem',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                gap: '1rem'
              }}>
                <div>
                  <strong>⚠️ Analysis Error:</strong> {error}
                </div>
                <button
                  onClick={clearError}
                  style={{
                    padding: '0.5rem 1rem',
                    backgroundColor: 'rgba(220, 38, 38, 0.2)',
                    color: '#fca5a5',
                    border: '1px solid rgba(220, 38, 38, 0.5)',
                    borderRadius: '4px',
                    cursor: 'pointer',
                    fontSize: '0.85rem',
                    whiteSpace: 'nowrap'
                  }}
                >
                  ✕ Dismiss
                </button>
              </div>
            )}

            {/* THE MIRROR - Upload Zone */}
            <div
              onDragOver={handleDragOver}
              onDragLeave={handleDragLeave}
              onDrop={handleDrop}
              className={`mirror-container ${isDragging ? 'dragging' : ''}`}
            >
              {/* Outer ring - animated glass border */}
              <div
                className="outer-ring"
                style={{
                  borderColor: `rgba(255, 255, 255, ${glowIntensity})`,
                  boxShadow: `
                    inset 0 0 60px rgba(0, 0, 0, 0.9),
                    inset -6px -6px 15px rgba(200, 200, 200, 0.1),
                    inset 6px 6px 15px rgba(0, 0, 0, 0.5),
                    0 0 20px rgba(255, 255, 255, ${glowIntensity * 0.5}),
                    0 0 20px rgba(255, 255, 255, ${glowIntensity * 0.5})
                  `
                }}
              >
                {/* Iris rings */}
                <div className="iris-ring-1" />
                <div className="iris-ring-2" />

                {/* Iris gradient layer */}
                <div className="iris-gradient" />

                {/* Pupil - responds to mouse */}
                <div
                  className="pupil"
                  style={{
                    transform: `translate(calc(-50% + ${pupilOffset.x}px), calc(-50% + ${pupilOffset.y}px))`,
                    left: '50%',
                    top: '50%'
                  }}
                >
                  {/* Digital iris pattern */}
                  <svg className="iris-pattern" viewBox="0 0 128 128" preserveAspectRatio="xMidYMid slice">
                    <defs>
                      <filter id="irisGlow">
                        <feGaussianBlur stdDeviation="1" />
                      </filter>
                    </defs>
                    {Array.from({ length: 24 }).map((_, i) => {
                      const angle = (i / 24) * Math.PI * 2
                      const x1 = 64 + Math.cos(angle) * 20
                      const y1 = 64 + Math.sin(angle) * 20
                      const x2 = 64 + Math.cos(angle) * 55
                      const y2 = 64 + Math.sin(angle) * 55
                      return (
                        <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke="rgba(100, 200, 255, 0.4)" strokeWidth="0.8" filter="url(#irisGlow)" />
                      )
                    })}
                    {Array.from({ length: 5 }).map((_, i) => (
                      <circle key={`ring-${i}`} cx="64" cy="64" r={25 + i * 7} fill="none" stroke="rgba(100, 200, 255, 0.25)" strokeWidth="0.6" />
                    ))}
                    {Array.from({ length: 12 }).map((_, i) => {
                      const angle = (i / 12) * Math.PI * 2 + Math.random() * 0.5
                      const radius = 30 + Math.random() * 15
                      const cx = 64 + Math.cos(angle) * radius
                      const cy = 64 + Math.sin(angle) * radius
                      return (
                        <circle key={`texture-${i}`} cx={cx} cy={cy} r={Math.random() * 3 + 1} fill="rgba(100, 200, 255, 0.3)" opacity="0.6" />
                      )
                    })}
                  </svg>

                  {/* Iris highlight */}
                  <div className="iris-highlight" />

                  {/* Center pupil dot - aggressively tracks cursor */}
                  <div
                    className="pupil-center"
                    style={{
                      width: `${pupilSize}px`,
                      height: `${pupilSize}px`,
                      transform: `translate(calc(-50% + ${innerPupilOffset.x}px), calc(-50% + ${innerPupilOffset.y}px))`,
                      left: '50%',
                      top: '50%'
                    }}
                  />
                </div>

                {/* Upload label */}
                <div className="upload-label">
                  <Upload className={`upload-icon ${isDragging ? 'active' : ''}`} />
                  <p className={`upload-text ${isDragging ? 'active' : ''}`}>
                    <ShinyText speed={5}>
                      {isAnalyzing ? 'ANALYZING' : isDragging ? 'ABSORBING' : isPremium ? 'UPLOAD' : 'PREMIUM'}
                    </ShinyText>
                  </p>
                  {!isPremium && (
                    <p className="premium-hint">
                      <ShinyText speed={5}>Click to upgrade</ShinyText>
                    </p>
                  )}
                </div>

                {/* File input */}
                <input
                  type="file"
                  multiple
                  accept=".txt,.csv,.json,.pdf,.html,.xml,.chat"
                  onChange={handleFileInput}
                  className="file-input-hidden"
                  id="file-input"
                  disabled={isAnalyzing}
                />
                <label htmlFor="file-input" className="file-input-label" />
              </div>
            </div>

            {/* File list */}
            {files.length > 0 && (
              <div className="file-list">
                <p className="file-list-title">
                  <ShinyText speed={5}>CONVERSATIONS LOADED • {files.length} FILE{files.length !== 1 ? 'S' : ''}</ShinyText>
                </p>
                <div className="file-items">
                  {files.map((file, idx) => (
                    <div key={idx} className="file-item">
                      <ShinyText speed={5}>▪ {file.name} • {(file.size / 1024).toFixed(1)} KB</ShinyText>
                    </div>
                  ))}
                </div>
                <button
                  className={`btn btn-analyze ${isAnalyzing ? 'loading' : ''}`}
                  onClick={handleAnalysisStart}
                  disabled={isAnalyzing}
                  style={{marginTop: '20px', padding: '12px 32px', fontSize: '14px'}}
                >
                  {isAnalyzing ? '⏳ ANALYZING...' : '🔮 ANALYZE NOW'}
                </button>
              </div>
            )}

            {/* Footer */}
            <div className="eye-footer">
              <p className="footer-text">
                <ShinyText speed={5}>BE CAREFUL WHAT YOU WISH FOR • YOU MIGHT NOT LIKE HOW THE MIRROR LOOKS BACK AT YOU</ShinyText>
              </p>
              <p className="footer-subtext">
                <ShinyText speed={5}>RELATIONSHIP ANALYZER • UPLOAD YEARS OF TEXT CONVERSATIONS TO REVEAL THE TRUTH</ShinyText>
              </p>
            </div>

            {/* Back button */}
            <button className="btn-back-eye" onClick={handleBackToChat}>
              ← Back to Chat
            </button>
          </div>
        )}
      </div>
    </>
  )
}