import { useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { useCharacters } from '@/hooks/useCharacters'
import { useChat } from '@/hooks/useChat'
import { paymentAPI } from '@/services/paymentAPI'
import { useNotification } from '@/hooks/useNotification'
import './SettingsModal.scss'

/**
 * SettingsModal Component
 * Comprehensive user settings and preferences with:
 * - Account management
 * - Character management (edit/delete)
 * - AI model settings
 * - Chat preferences
 * - Data & privacy controls
 * - Premium features
 */

export default function SettingsModal({ modalId, onClose }) {
  const { user, updateProfile } = useAuth()
  const { characters, deleteCharacterData, updateCharacterData } = useCharacters()
  const { conversations } = useChat()
  const notification = useNotification()
  const [activeTab, setActiveTab] = useState('account')
  const [isProcessingPayment, setIsProcessingPayment] = useState(false)
  const [editingCharacter, setEditingCharacter] = useState(null)
  const [characterToDelete, setCharacterToDelete] = useState(null)
  const isPremium = user?.isPremium ?? false // Get from auth context
  const [settings, setSettings] = useState({
    theme: 'dark',
    notifications: true,
    autoSave: true,
    experimentalFeatures: false,
    // AI Settings
    temperature: 0.7,
    maxTokens: 2048,
    modelType: 'default',
    // Chat Settings
    fontSize: 'medium',
    showTimestamps: true,
    enableTypingIndicator: true,
    autoScroll: true,
    messageGrouping: true
  })

  const handleSettingChange = (key, value) => {
    if (typeof value === 'boolean' || value === undefined) {
      setSettings((prev) => ({ ...prev, [key]: !prev[key] }))
    } else {
      setSettings((prev) => ({ ...prev, [key]: value }))
    }
  }

  // Character Management Handlers
  const handleEditCharacter = (character) => {
    setEditingCharacter({...character})
  }

  const handleSaveCharacter = async () => {
    if (!editingCharacter) return

    try {
      await updateCharacterData(editingCharacter.id, {
        name: editingCharacter.name,
        bio: editingCharacter.bio,
        personality: editingCharacter.personality,
        avatar: editingCharacter.avatar
      })
      notification.success('Character updated successfully!')
      setEditingCharacter(null)
    } catch (error) {
      notification.error('Failed to update character: ' + error.message)
    }
  }

  const handleDeleteCharacter = async (characterId) => {
    try {
      await deleteCharacterData(characterId)
      notification.success('Character deleted successfully')
      setCharacterToDelete(null)
    } catch (error) {
      notification.error('Failed to delete character: ' + error.message)
    }
  }

  const handleExportConversations = () => {
    try {
      const dataStr = JSON.stringify(conversations, null, 2)
      const dataBlob = new Blob([dataStr], { type: 'application/json' })
      const url = URL.createObjectURL(dataBlob)
      const link = document.createElement('a')
      link.href = url
      link.download = `justlayme-conversations-${new Date().toISOString().split('T')[0]}.json`
      link.click()
      URL.revokeObjectURL(url)
      notification.success('Conversations exported successfully!')
    } catch (error) {
      notification.error('Failed to export conversations: ' + error.message)
    }
  }

  const handleUpgradeToPremium = async () => {
    setIsProcessingPayment(true)
    try {
      // Create subscription with payment API
      const result = await paymentAPI.createSubscription('price_monthly_premium')

      if (result.clientSecret) {
        notification.success('Subscription created! Redirecting to payment...')
        // In a real implementation, you would:
        // 1. Redirect to Stripe payment page
        // 2. Or open a modal with embedded Stripe form
        // For now, simulate successful payment
        setTimeout(() => {
          // Simulate payment success
          updateProfile({ isPremium: true })
          notification.success('✨ Welcome to Premium!')
          setActiveTab('premium')
        }, 2000)
      }
    } catch (error) {
      notification.error('Failed to process subscription: ' + (error.message || 'Unknown error'))
    } finally {
      setIsProcessingPayment(false)
    }
  }

  const PremiumBadge = () => (
    <span className="premium-badge">✨ Premium</span>
  )

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content settings-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Settings</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <div className="settings-container">
          {/* Sidebar Tabs */}
          <div className="settings-sidebar">
            <button
              className={`settings-tab ${activeTab === 'account' ? 'active' : ''}`}
              onClick={() => setActiveTab('account')}
            >
              👤 Account
            </button>
            <button
              className={`settings-tab ${activeTab === 'characters' ? 'active' : ''}`}
              onClick={() => setActiveTab('characters')}
            >
              🎭 Characters
            </button>
            <button
              className={`settings-tab ${activeTab === 'ai-settings' ? 'active' : ''}`}
              onClick={() => setActiveTab('ai-settings')}
            >
              🤖 AI Settings
            </button>
            <button
              className={`settings-tab ${activeTab === 'chat-settings' ? 'active' : ''}`}
              onClick={() => setActiveTab('chat-settings')}
            >
              💬 Chat
            </button>
            <button
              className={`settings-tab ${activeTab === 'preferences' ? 'active' : ''}`}
              onClick={() => setActiveTab('preferences')}
            >
              ⚙️ Preferences
            </button>
            <button
              className={`settings-tab ${activeTab === 'data' ? 'active' : ''}`}
              onClick={() => setActiveTab('data')}
            >
              📊 Data & Privacy
            </button>
            <button
              className={`settings-tab ${activeTab === 'premium' ? 'active' : ''}`}
              onClick={() => setActiveTab('premium')}
            >
              ✨ Premium
            </button>
          </div>

          {/* Content Area */}
          <div className="settings-content">
            {/* Account Tab */}
            {activeTab === 'account' && (
              <div className="settings-section">
                <h3>Account Settings</h3>
                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Email</p>
                    <p className="setting-value">{user?.email || 'Not set'}</p>
                  </div>
                </div>
                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Account Status</p>
                    <p className="setting-value">
                      {isPremium ? (
                        <span className="status-premium">✨ Premium</span>
                      ) : (
                        <span className="status-free">Free</span>
                      )}
                    </p>
                  </div>
                </div>
                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Password</p>
                    <p className="setting-value">••••••••</p>
                  </div>
                  <button className="btn-text">Change</button>
                </div>
                <div className="setting-item">
                  <button className="btn-secondary full-width">Logout</button>
                </div>
              </div>
            )}

            {/* Preferences Tab */}
            {activeTab === 'preferences' && (
              <div className="settings-section">
                <h3>Preferences</h3>
                <div className="setting-item toggle">
                  <div className="setting-info">
                    <p className="setting-label">Notifications</p>
                    <p className="setting-description">Get notified about new messages</p>
                  </div>
                  <label className="toggle-switch">
                    <input
                      type="checkbox"
                      checked={settings.notifications}
                      onChange={() => handleSettingChange('notifications')}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                </div>

                <div className="setting-item toggle">
                  <div className="setting-info">
                    <p className="setting-label">Auto-Save</p>
                    <p className="setting-description">Automatically save conversations</p>
                  </div>
                  <label className="toggle-switch">
                    <input
                      type="checkbox"
                      checked={settings.autoSave}
                      onChange={() => handleSettingChange('autoSave')}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                </div>

                <div className="setting-item toggle">
                  <div className="setting-info">
                    <p className="setting-label">Experimental Features</p>
                    <p className="setting-description">Try beta features early</p>
                  </div>
                  <label className="toggle-switch">
                    <input
                      type="checkbox"
                      checked={settings.experimentalFeatures}
                      onChange={() => handleSettingChange('experimentalFeatures')}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                </div>
              </div>
            )}

            {/* Characters Tab */}
            {activeTab === 'characters' && (
              <div className="settings-section">
                <h3>Manage Characters</h3>
                <p className="section-description">Edit or delete your custom AI characters</p>

                {characters.length === 0 ? (
                  <div className="empty-state">
                    <p>No custom characters yet</p>
                    <p className="text-sm">Create your first character to get started!</p>
                  </div>
                ) : (
                  <div className="character-list">
                    {characters.map((character) => (
                      <div key={character.id} className="character-item">
                        <div className="character-avatar">
                          {character.avatar || '🎭'}
                        </div>
                        <div className="character-info">
                          <p className="character-name">{character.name}</p>
                          <p className="character-bio">{character.bio?.substring(0, 50)}...</p>
                        </div>
                        <div className="character-actions">
                          <button
                            className="btn-icon"
                            onClick={() => handleEditCharacter(character)}
                            title="Edit character"
                          >
                            ✏️
                          </button>
                          <button
                            className="btn-icon danger"
                            onClick={() => setCharacterToDelete(character.id)}
                            title="Delete character"
                          >
                            🗑️
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                {/* Edit Character Modal */}
                {editingCharacter && (
                  <div className="inline-modal">
                    <h4>Edit Character</h4>
                    <div className="form-group">
                      <label>Name</label>
                      <input
                        type="text"
                        value={editingCharacter.name}
                        onChange={(e) => setEditingCharacter({...editingCharacter, name: e.target.value})}
                      />
                    </div>
                    <div className="form-group">
                      <label>Bio</label>
                      <textarea
                        value={editingCharacter.bio}
                        onChange={(e) => setEditingCharacter({...editingCharacter, bio: e.target.value})}
                        rows={3}
                      />
                    </div>
                    <div className="form-group">
                      <label>Personality</label>
                      <textarea
                        value={editingCharacter.personality}
                        onChange={(e) => setEditingCharacter({...editingCharacter, personality: e.target.value})}
                        rows={2}
                      />
                    </div>
                    <div className="form-actions">
                      <button className="btn-secondary" onClick={() => setEditingCharacter(null)}>Cancel</button>
                      <button className="btn-primary" onClick={handleSaveCharacter}>Save Changes</button>
                    </div>
                  </div>
                )}

                {/* Delete Confirmation */}
                {characterToDelete && (
                  <div className="inline-modal danger">
                    <h4>⚠️ Delete Character?</h4>
                    <p>This will permanently delete this character and all associated conversations. This cannot be undone.</p>
                    <div className="form-actions">
                      <button className="btn-secondary" onClick={() => setCharacterToDelete(null)}>Cancel</button>
                      <button className="btn-danger" onClick={() => handleDeleteCharacter(characterToDelete)}>Delete Permanently</button>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* AI Settings Tab */}
            {activeTab === 'ai-settings' && (
              <div className="settings-section">
                <h3>AI Model Settings</h3>
                <p className="section-description">Customize AI behavior and response generation</p>

                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Model Type</p>
                    <p className="setting-description">Choose the AI model for conversations</p>
                  </div>
                  <select
                    value={settings.modelType}
                    onChange={(e) => handleSettingChange('modelType', e.target.value)}
                    className="setting-select"
                  >
                    <option value="default">Default (GPT-4)</option>
                    <option value="fast">Fast (GPT-3.5 Turbo)</option>
                    <option value="creative">Creative (Higher Temperature)</option>
                  </select>
                </div>

                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Temperature: {settings.temperature}</p>
                    <p className="setting-description">Controls randomness (0 = focused, 1 = creative)</p>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.1"
                    value={settings.temperature}
                    onChange={(e) => handleSettingChange('temperature', parseFloat(e.target.value))}
                    className="setting-slider"
                  />
                </div>

                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Max Response Length: {settings.maxTokens} tokens</p>
                    <p className="setting-description">Maximum length of AI responses</p>
                  </div>
                  <input
                    type="range"
                    min="256"
                    max="4096"
                    step="256"
                    value={settings.maxTokens}
                    onChange={(e) => handleSettingChange('maxTokens', parseInt(e.target.value))}
                    className="setting-slider"
                  />
                </div>
              </div>
            )}

            {/* Chat Settings Tab */}
            {activeTab === 'chat-settings' && (
              <div className="settings-section">
                <h3>Chat Display Settings</h3>
                <p className="section-description">Customize how conversations are displayed</p>

                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Font Size</p>
                    <p className="setting-description">Adjust message text size</p>
                  </div>
                  <select
                    value={settings.fontSize}
                    onChange={(e) => handleSettingChange('fontSize', e.target.value)}
                    className="setting-select"
                  >
                    <option value="small">Small</option>
                    <option value="medium">Medium</option>
                    <option value="large">Large</option>
                  </select>
                </div>

                <div className="setting-item toggle">
                  <div className="setting-info">
                    <p className="setting-label">Show Timestamps</p>
                    <p className="setting-description">Display time for each message</p>
                  </div>
                  <label className="toggle-switch">
                    <input
                      type="checkbox"
                      checked={settings.showTimestamps}
                      onChange={() => handleSettingChange('showTimestamps')}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                </div>

                <div className="setting-item toggle">
                  <div className="setting-info">
                    <p className="setting-label">Typing Indicator</p>
                    <p className="setting-description">Show when AI is typing</p>
                  </div>
                  <label className="toggle-switch">
                    <input
                      type="checkbox"
                      checked={settings.enableTypingIndicator}
                      onChange={() => handleSettingChange('enableTypingIndicator')}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                </div>

                <div className="setting-item toggle">
                  <div className="setting-info">
                    <p className="setting-label">Auto-scroll</p>
                    <p className="setting-description">Automatically scroll to new messages</p>
                  </div>
                  <label className="toggle-switch">
                    <input
                      type="checkbox"
                      checked={settings.autoScroll}
                      onChange={() => handleSettingChange('autoScroll')}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                </div>

                <div className="setting-item toggle">
                  <div className="setting-info">
                    <p className="setting-label">Group Messages</p>
                    <p className="setting-description">Group consecutive messages from same sender</p>
                  </div>
                  <label className="toggle-switch">
                    <input
                      type="checkbox"
                      checked={settings.messageGrouping}
                      onChange={() => handleSettingChange('messageGrouping')}
                    />
                    <span className="toggle-slider"></span>
                  </label>
                </div>
              </div>
            )}

            {/* Data & Privacy Tab */}
            {activeTab === 'data' && (
              <div className="settings-section">
                <h3>Data & Privacy</h3>
                <p className="section-description">Manage your data and privacy settings</p>

                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Export Conversations</p>
                    <p className="setting-description">Download all your conversations as JSON</p>
                  </div>
                  <button className="btn-secondary" onClick={handleExportConversations}>
                    📥 Export Data
                  </button>
                </div>

                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Conversation Statistics</p>
                    <p className="setting-description">Total conversations: {conversations.length}</p>
                  </div>
                </div>

                <div className="setting-item">
                  <div className="setting-info">
                    <p className="setting-label">Character Statistics</p>
                    <p className="setting-description">Total characters: {characters.length}</p>
                  </div>
                </div>

                <div className="setting-item danger-zone">
                  <div className="setting-info">
                    <p className="setting-label danger">⚠️ Danger Zone</p>
                    <p className="setting-description">Irreversible actions - use with caution</p>
                  </div>
                </div>

                <div className="setting-item">
                  <button className="btn-danger full-width" onClick={() => {
                    if (confirm('Are you sure you want to delete your account? This cannot be undone.')) {
                      notification.error('Account deletion is not yet implemented')
                    }
                  }}>
                    Delete Account
                  </button>
                </div>
              </div>
            )}

            {/* Premium Tab */}
            {activeTab === 'premium' && (
              <div className="settings-section premium-section">
                {!isPremium ? (
                  <>
                    <h3>Unlock Premium</h3>
                    <p className="premium-description">
                      Get exclusive features and unlimited access to all AI characters.
                    </p>

                    <div className="premium-features">
                      <div className="feature-item">
                        <span className="feature-icon">♾️</span>
                        <div className="feature-text">
                          <p className="feature-name">Unlimited Conversations</p>
                          <p className="feature-desc">Chat with any character anytime</p>
                        </div>
                      </div>

                      <div className="feature-item">
                        <span className="feature-icon">🔊</span>
                        <div className="feature-text">
                          <p className="feature-name">Voice Cloning</p>
                          <p className="feature-desc">Clone your voice for natural interactions</p>
                        </div>
                      </div>

                      <div className="feature-item">
                        <span className="feature-icon">🎭</span>
                        <div className="feature-text">
                          <p className="feature-name">Unlimited Characters</p>
                          <p className="feature-desc">Create and customize unlimited AI personas</p>
                        </div>
                      </div>

                      <div className="feature-item">
                        <span className="feature-icon">🪞</span>
                        <div className="feature-text">
                          <p className="feature-name">The Grey Mirror Pro</p>
                          <p className="feature-desc">Advanced relationship analysis with insights</p>
                        </div>
                      </div>

                      <div className="feature-item">
                        <span className="feature-icon">⚡</span>
                        <div className="feature-text">
                          <p className="feature-name">Priority Support</p>
                          <p className="feature-desc">Get help from our support team</p>
                        </div>
                      </div>
                    </div>

                    <div className="pricing-card">
                      <div className="price">$9.99<span>/month</span></div>
                      <button
                        className="btn-primary full-width"
                        onClick={handleUpgradeToPremium}
                        disabled={isProcessingPayment}
                      >
                        {isProcessingPayment ? 'Processing...' : 'Upgrade to Premium'}
                      </button>
                      <p className="pricing-note">Cancel anytime. No hidden fees.</p>
                    </div>
                  </>
                ) : (
                  <>
                    <h3>Premium Active</h3>
                    <div className="premium-status">
                      <p className="status-message">✨ You have access to all premium features!</p>
                      <p className="renewal-info">Your subscription renews on December 13, 2025</p>
                    </div>
                    <button className="btn-secondary full-width">Manage Subscription</button>
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
