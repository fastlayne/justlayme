import { useState } from 'react'
import { useNotification } from '@/hooks/useNotification'
import FileDropZone from './FileDropZone'
import ShinyText from '@/components/common/ShinyText'
import ShapeBlur from '@/components/common/ShapeBlur'
import './UploadSection.scss'

/**
 * UploadSection Component
 * Three upload methods: paste text, file upload, screenshot OCR
 * New architecture: Passes data to parent's onAnalysisStart for ML orchestrator processing
 *
 * PERSONALIZATION FIELDS:
 * - userName: The user's name for personalized metrics
 * - contactName: The person they're messaging
 * - insightsGoal: What specific insights the user wants from the analysis
 */

const UPLOAD_METHODS = {
  PASTE: 'paste',
  FILE: 'file',
  SCREENSHOT: 'screenshot',
}

export default function UploadSection({ onAnalysisStart = () => {} }) {
  const [activeMethod, setActiveMethod] = useState(UPLOAD_METHODS.PASTE)
  const [pastedText, setPastedText] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  // Personalization fields
  const [userName, setUserName] = useState('')
  const [contactName, setContactName] = useState('')
  const [insightsGoal, setInsightsGoal] = useState('')

  const notification = useNotification()

  // Build personalization metadata object
  const getPersonalizationData = () => ({
    userName: userName.trim() || 'You',
    contactName: contactName.trim() || 'Them',
    insightsGoal: insightsGoal.trim() || '',
  })

  // Handle paste upload
  const handlePasteUpload = async () => {
    if (!pastedText.trim()) {
      notification.warning('Please paste some conversation data')
      return
    }

    setIsLoading(true)
    try {
      // Pass data with personalization to parent's ML orchestrator handler
      await onAnalysisStart(pastedText.trim(), 'paste', getPersonalizationData())
      notification.success('Analysis started! Processing your data...')
      setPastedText('')
    } catch (error) {
      notification.error(error?.message || 'Failed to start analysis')
    } finally {
      setIsLoading(false)
    }
  }

  // Handle file upload
  const handleFileUpload = async (file) => {
    setIsLoading(true)
    try {
      const reader = new FileReader()
      reader.onload = async (e) => {
        try {
          const content = e.target.result
          // ARCHITECTURAL FIX: Validate content before processing
          if (!content || typeof content !== 'string') {
            throw new Error('Invalid file content')
          }
          // Pass data with personalization to parent's ML orchestrator handler
          await onAnalysisStart(content, 'file', getPersonalizationData())
          notification.success('Analysis started! Processing your file...')
        } catch (analysisError) {
          // ARCHITECTURAL FIX: Catch errors in onload callback
          console.error('Analysis error:', analysisError)
          notification.error(analysisError?.message || 'Failed to analyze file')
        } finally {
          // ARCHITECTURAL FIX: Reset loading state after analysis
          setIsLoading(false)
        }
      }
      reader.onerror = () => {
        // ARCHITECTURAL FIX: Handle FileReader errors
        notification.error('Failed to read file')
        setIsLoading(false)
      }
      reader.readAsText(file)
    } catch (error) {
      console.error('File upload error:', error)
      notification.error(error?.message || 'Failed to upload file')
      setIsLoading(false)
    }
  }

  // Handle screenshot upload
  const handleScreenshotUpload = async (file) => {
    setIsLoading(true)
    try {
      // For screenshots, we can pass the file itself or a base64 string
      // The parent's ML orchestrator will handle OCR processing
      const reader = new FileReader()
      reader.onload = async (e) => {
        const content = e.target.result
        await onAnalysisStart(content, 'screenshot', getPersonalizationData())
        notification.success('Screenshot processed! Analysis started...')
      }
      reader.readAsDataURL(file)
    } catch (error) {
      notification.error(error?.message || 'Failed to process screenshot')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <ShapeBlur thickness="thinnest">
    <div className="upload-section">
      {/* Section Header */}
      <div className="section-header">
        <h2><ShinyText speed={5}>Upload Conversation Data</ShinyText></h2>
        <p><ShinyText speed={5}>Choose how you want to upload your conversation data for analysis</ShinyText></p>
      </div>

      {/* Helpful Instructions */}
      <div className="upload-instructions">
        <h3>How to Export Your Conversations</h3>

        <div className="export-guides">
          <div className="guide-section">
            <h4>iPhone/iMessage</h4>
            <ol>
              <li>Open the conversation in Messages</li>
              <li>Tap the contact's name at the top</li>
              <li>Scroll down and tap "Export Chat"</li>
              <li>Select "Without Media" for faster processing</li>
              <li>Save as .txt file and upload here</li>
            </ol>
            <p className="tip"><strong>Tip:</strong> iMessage exports are in the format "Sender: Message" which works perfectly!</p>
          </div>

          <div className="guide-section">
            <h4>WhatsApp</h4>
            <ol>
              <li>Open the chat you want to analyze</li>
              <li>Tap the three dots menu (Android) or contact name (iPhone)</li>
              <li>Select "More" then "Export Chat"</li>
              <li>Choose "Without Media"</li>
              <li>Save and upload the .txt file</li>
            </ol>
            <p className="tip"><strong>Format:</strong> "[Date, Time] Name: Message" works great!</p>
          </div>

          <div className="guide-section">
            <h4>Instagram/Facebook Messenger</h4>
            <ol>
              <li>Go to Settings then Privacy then Download Your Information</li>
              <li>Select "Messages" only</li>
              <li>Choose JSON format</li>
              <li>Wait for download link (can take up to 24 hours)</li>
              <li>Upload the messages.json file</li>
            </ol>
            <p className="tip"><strong>Note:</strong> JSON files are automatically parsed correctly!</p>
          </div>

          <div className="guide-section">
            <h4>Android SMS</h4>
            <ol>
              <li>Install "SMS Backup & Restore" app</li>
              <li>Open app and tap "Backup"</li>
              <li>Select the conversation</li>
              <li>Choose .txt or .xml format</li>
              <li>Share/upload the file here</li>
            </ol>
          </div>
        </div>

        <div className="format-requirements">
          <h4>Supported Formats</h4>
          <ul>
            <li><strong>Text Files (.txt):</strong> Any format with "Name: Message" or "From/To" structure</li>
            <li><strong>JSON Files (.json):</strong> Messenger exports, custom formats with sender/message fields</li>
            <li><strong>CSV Files (.csv):</strong> Spreadsheet exports with timestamp, sender, message columns</li>
            <li><strong>Paste Text:</strong> Copy-paste directly from any chat app</li>
          </ul>
        </div>

        <div className="best-practices">
          <h4>Tips for Best Results</h4>
          <ul>
            <li><strong>Include at least 100 messages</strong> for meaningful analysis</li>
            <li><strong>Export full conversations</strong> - more data = better insights</li>
            <li><strong>Enter both names accurately</strong> above - this ensures metrics are attributed correctly</li>
            <li><strong>Keep timestamps if possible</strong> - they enable time-based analysis</li>
            <li><strong>One conversation at a time</strong> - don't mix multiple people in one upload</li>
          </ul>
        </div>
      </div>

      {/* Personalization Fields */}
      <div className="personalization-fields">
        <div className="name-fields">
          <div className="field-group">
            <label htmlFor="userName">
              <ShinyText speed={5} className="variant-subtle">Your Name</ShinyText>
            </label>
            <input
              type="text"
              id="userName"
              placeholder="Enter your name..."
              value={userName}
              onChange={(e) => setUserName(e.target.value)}
              disabled={isLoading}
              className="personalization-input"
            />
          </div>
          <div className="field-group">
            <label htmlFor="contactName">
              <ShinyText speed={5} className="variant-subtle">Their Name</ShinyText>
            </label>
            <input
              type="text"
              id="contactName"
              placeholder="Who are you messaging..."
              value={contactName}
              onChange={(e) => setContactName(e.target.value)}
              disabled={isLoading}
              className="personalization-input"
            />
          </div>
        </div>
        <div className="field-group insights-field">
          <label htmlFor="insightsGoal">
            <ShinyText speed={5} className="variant-subtle">What insights are you looking for?</ShinyText>
          </label>
          <textarea
            id="insightsGoal"
            placeholder="e.g., 'Are they actually interested in me?', 'Is this relationship healthy?', 'Why do we keep arguing about the same things?'"
            value={insightsGoal}
            onChange={(e) => setInsightsGoal(e.target.value)}
            disabled={isLoading}
            className="insights-textarea"
            rows={3}
          />
        </div>
      </div>

      {/* Method Tabs */}
      <div className="upload-tabs">
        {Object.values(UPLOAD_METHODS).map((method) => (
          <button
            key={method}
            className={`tab-button ${activeMethod === method ? 'active' : ''}`}
            onClick={() => setActiveMethod(method)}
            disabled={isLoading}
          >
            {method === 'paste' && '📋 Paste Text'}
            {method === 'file' && '📁 Upload File'}
            {method === 'screenshot' && '📸 Screenshot OCR'}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div className="tab-content">
        {/* Paste Method */}
        {activeMethod === UPLOAD_METHODS.PASTE && (
          <div className="method-pane">
            <div className="method-info">
              <p><ShinyText speed={5} className="variant-subtle">Paste your conversation text directly here. Support for:</ShinyText></p>
              <ul>
                <li><ShinyText speed={5} className="variant-subtle">SMS conversations</ShinyText></li>
                <li><ShinyText speed={5} className="variant-subtle">iMessage exports</ShinyText></li>
                <li><ShinyText speed={5} className="variant-subtle">Chat logs (Discord, Slack, WhatsApp, etc.)</ShinyText></li>
              </ul>
            </div>

            <textarea
              className="paste-textarea"
              placeholder="Paste your conversation here... (minimum 100 characters for meaningful analysis)"
              value={pastedText}
              onChange={(e) => setPastedText(e.target.value)}
              disabled={isLoading}
              rows={12}
            />

            <div className="text-stats">
              <span>{pastedText.length} characters</span>
            </div>

            <button
              type="button"
              className="btn btn-primary btn-submit"
              onClick={(e) => {
                e.preventDefault()
                e.stopPropagation()
                console.log('🔘 Paste analyze button clicked')
                handlePasteUpload()
              }}
              disabled={isLoading || !pastedText.trim()}
              style={{ touchAction: 'manipulation' }}
            >
              {isLoading ? '⏳ Analyzing...' : '🚀 Analyze Conversation'}
            </button>
          </div>
        )}

        {/* File Method */}
        {activeMethod === UPLOAD_METHODS.FILE && (
          <div className="method-pane">
            <div className="method-info">
              <p><ShinyText speed={5} className="variant-subtle">Upload a file with your conversation data:</ShinyText></p>
              <ul>
                <li><ShinyText speed={5} className="variant-subtle">JSON format with conversation objects</ShinyText></li>
                <li><ShinyText speed={5} className="variant-subtle">CSV files with messages</ShinyText></li>
                <li><ShinyText speed={5} className="variant-subtle">Plain text logs</ShinyText></li>
              </ul>
            </div>

            <FileDropZone
              onFileSelect={handleFileUpload}
              acceptedFormats=".json,.csv,.txt"
              maxSizemb={50}
              label="Drop your conversation file here"
            />

            <p className="upload-hint">
              <ShinyText speed={5} className="variant-subtle">Ensure your file is in a supported format and under 50MB</ShinyText>
            </p>
          </div>
        )}

        {/* Screenshot Method */}
        {activeMethod === UPLOAD_METHODS.SCREENSHOT && (
          <div className="method-pane">
            <div className="method-info">
              <p><ShinyText speed={5} className="variant-subtle">Upload a screenshot of conversations for OCR analysis:</ShinyText></p>
              <ul>
                <li><ShinyText speed={5} className="variant-subtle">PNG, JPG, GIF formats supported</ShinyText></li>
                <li><ShinyText speed={5} className="variant-subtle">Automatic text extraction (OCR)</ShinyText></li>
                <li><ShinyText speed={5} className="variant-subtle">Maximum 10MB file size</ShinyText></li>
              </ul>
            </div>

            <FileDropZone
              onFileSelect={handleScreenshotUpload}
              acceptedFormats="image/*"
              maxSizemb={10}
              label="Drop your screenshot here"
            />

            <p className="upload-hint">
              <ShinyText speed={5} className="variant-subtle">Screenshots must be clear and readable for best OCR results</ShinyText>
            </p>
          </div>
        )}
      </div>

      {/* Privacy Note */}
      <div className="privacy-note">
        <p>
          🔒 <strong>Privacy:</strong> <ShinyText speed={5} className="variant-subtle">Your data is processed securely and only used for this analysis. No data is stored or shared.</ShinyText>
        </p>
      </div>
    </div>
    </ShapeBlur>
  )
}
