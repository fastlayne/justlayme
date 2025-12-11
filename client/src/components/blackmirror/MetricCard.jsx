import { useState } from 'react'
import './MetricCard.scss'

/**
 * MetricCard Component
 * Individual metric display with expandable details
 * ENHANCED: Now supports per-person breakdowns with sections
 *
 * Details can now be:
 * - Array of {label, value} for simple details
 * - Object with {you: {...}, them: {...}, comparison: {...}} for per-person breakdowns
 */

export default function MetricCard({
  title = 'Metric',
  icon = null, // Removed default emoji for elegant design
  value = '0%',
  description = '',
  details = [],
  sections = null, // NEW: Per-person breakdown sections
  comparison = null, // NEW: Comparison data
  summary = '', // NEW: Summary text
  isExpanded = false,
  onToggle = () => {},
  // PERSONALIZATION: Custom names for metrics display
  userName = 'You',
  contactName = 'Them',
}) {
  // Auto-show preview of key data in collapsed state
  const previewData = []
  if (sections?.you) {
    Object.entries(sections.you).slice(0, 2).forEach(([k, v]) => {
      previewData.push(`${userName}: ${formatValue(v, userName, contactName, k)}`)
    })
  }
  if (sections?.them) {
    Object.entries(sections.them).slice(0, 2).forEach(([k, v]) => {
      previewData.push(`${contactName}: ${formatValue(v, userName, contactName, k)}`)
    })
  }

  return (
    <div className={`metric-card ${isExpanded ? 'expanded' : ''}`}>
      <div className="card-header" onClick={onToggle}>
        <div className="header-left">
          {icon && <span className="metric-icon">{icon}</span>}
          <div className="header-text">
            <h3 className="metric-title">{title}</h3>
            <p className="metric-value">{value}</p>
            {!isExpanded && previewData.length > 0 && (
              <p className="metric-preview">{previewData.join(', ')}</p>
            )}
          </div>
        </div>
        <div className="expand-icon">{isExpanded ? '−' : '+'}</div>
      </div>

      {isExpanded && (
        <div className="card-content">
          {description && <p className="metric-description">{description}</p>}

          {/* Summary */}
          {summary && <p className="metric-summary">{summary}</p>}

          {/* Per-person sections (new enhanced display) */}
          {sections && (sections.you || sections.them) && (
            <div className="person-sections">
              {/* Your metrics */}
              {sections.you && Object.keys(sections.you).length > 0 && (
                <div className="person-section you-section">
                  <h4 className="section-title">{userName}</h4>
                  <div className="section-details">
                    {Object.entries(sections.you)
                      .filter(([k, v]) => v !== null && v !== undefined && v !== '')
                      .map(([key, val], idx) => (
                        <div key={idx} className="detail-item">
                          <span className="detail-label">{formatLabel(key)}:</span>
                          <span className="detail-value">{formatValue(val, userName, contactName, key)}</span>
                        </div>
                      ))}
                  </div>
                </div>
              )}

              {/* Their metrics */}
              {sections.them && Object.keys(sections.them).length > 0 && (
                <div className="person-section them-section">
                  <h4 className="section-title">{contactName}</h4>
                  <div className="section-details">
                    {Object.entries(sections.them)
                      .filter(([k, v]) => v !== null && v !== undefined && v !== '')
                      .map(([key, val], idx) => (
                        <div key={idx} className="detail-item">
                          <span className="detail-label">{formatLabel(key)}:</span>
                          <span className="detail-value">{formatValue(val, userName, contactName, key)}</span>
                        </div>
                      ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Comparison section */}
          {comparison && (
            <div className="comparison-section">
              <h4 className="section-title">Comparison</h4>
              <div className="section-details">
                {Object.entries(comparison).map(([key, val], idx) => (
                  <div key={idx} className="detail-item comparison-item">
                    <span className="detail-label">{formatLabel(key)}:</span>
                    <span className={`detail-value ${getComparisonClass(key, val)}`}>
                      {formatComparisonValue(key, val, userName, contactName)}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Legacy flat details support */}
          {details && details.length > 0 && (
            <div className="metric-details">
              {details.map((detail, idx) => (
                <div key={idx} className="detail-item">
                  <span className="detail-label">{detail.label}:</span>
                  <span className="detail-value">{detail.value}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

/**
 * Format camelCase or snake_case to readable label
 */
function formatLabel(key) {
  return key
    .replace(/([A-Z])/g, ' $1')
    .replace(/_/g, ' ')
    .replace(/^./, (str) => str.toUpperCase())
    .trim()
}

/**
 * Format value for display
 * PERSONALIZATION: Now accepts custom names for you/them display
 * ARCHITECTURAL FIX: Don't assume all integers 0-100 are percentages
 * Only show % for fields that are explicitly percentages
 */
function formatValue(val, userName = 'You', contactName = 'Them', fieldName = '') {
  if (val === null || val === undefined) return '—'
  if (typeof val === 'boolean') return val ? 'Yes' : 'No'
  if (typeof val === 'number') {
    // Only show percentage for fields that ARE percentages
    const percentageFields = ['rate', 'ratio', 'percentage', 'percent', 'doubleTextRate', 'score']
    const isPercentageField = percentageFields.some(p =>
      fieldName.toLowerCase().includes(p)
    )

    if (isPercentageField && val >= 0 && val <= 100) {
      return `${val.toFixed(1)}%`
    }

    // Format large numbers with commas
    if (val >= 1000) {
      return val.toLocaleString()
    }

    // Format decimals
    if (!Number.isInteger(val)) return val.toFixed(1)

    // Plain integer - no percentage suffix
    return String(val)
  }
  if (Array.isArray(val)) {
    if (val.length === 0) return 'None'
    // Format array items individually
    return val.map(item => {
      if (typeof item === 'object' && item !== null) {
        return JSON.stringify(item)
      }
      return String(item)
    }).join(', ')
  }
  if (typeof val === 'object') {
    // Handle ratio objects {you: X, them: Y}
    if (val.you !== undefined && val.them !== undefined) {
      return `${userName}: ${formatValue(val.you, userName, contactName, fieldName)} / ${contactName}: ${formatValue(val.them, userName, contactName, fieldName)}`
    }
    // Format nested objects as key: value pairs
    const entries = Object.entries(val)
    if (entries.length === 0) return 'None'
    return entries.map(([k, v]) => {
      const formattedKey = k.replace(/_/g, ' ').replace(/([A-Z])/g, ' $1').trim()
      const formattedValue = typeof v === 'object' ? JSON.stringify(v) : String(v)
      return `${formattedKey}: ${formattedValue}`
    }).join(', ')
  }
  return String(val)
}

/**
 * Format comparison values with context
 * PERSONALIZATION: Now accepts custom names
 */
function formatComparisonValue(key, val, userName = 'You', contactName = 'Them') {
  if (val === 'you') return userName
  if (val === 'them') return contactName
  if (val === 'equal') return 'Equal'
  return formatValue(val, userName, contactName)
}

/**
 * Get CSS class for comparison highlighting
 */
function getComparisonClass(key, val) {
  if (val === 'you') return 'highlight-you'
  if (val === 'them') return 'highlight-them'
  if (val === 'equal') return 'highlight-equal'
  return ''
}
