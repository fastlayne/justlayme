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
  return (
    <div className={`metric-card ${isExpanded ? 'expanded' : ''}`}>
      <div className="card-header" onClick={onToggle}>
        <div className="header-left">
          {icon && <span className="metric-icon">{icon}</span>}
          <div className="header-text">
            <h3 className="metric-title">{title}</h3>
            <p className="metric-value">{value}</p>
          </div>
        </div>
        <div className="expand-icon">{isExpanded ? '−' : '+'}</div>
      </div>

      {isExpanded && (
        <div className="card-content">
          {description && <p className="metric-description">{description}</p>}

          {/* Per-person sections (new enhanced display) */}
          {sections && (
            <div className="person-sections">
              {/* Your metrics */}
              {sections.you && (
                <div className="person-section you-section">
                  <h4 className="section-title">{userName}</h4>
                  <div className="section-details">
                    {Object.entries(sections.you).map(([key, val], idx) => (
                      <div key={idx} className="detail-item">
                        <span className="detail-label">{formatLabel(key)}:</span>
                        <span className="detail-value">{formatValue(val, userName, contactName)}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Their metrics */}
              {sections.them && (
                <div className="person-section them-section">
                  <h4 className="section-title">{contactName}</h4>
                  <div className="section-details">
                    {Object.entries(sections.them).map(([key, val], idx) => (
                      <div key={idx} className="detail-item">
                        <span className="detail-label">{formatLabel(key)}:</span>
                        <span className="detail-value">{formatValue(val, userName, contactName)}</span>
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

          {/* Summary */}
          {summary && <p className="metric-summary">{summary}</p>}
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
 */
function formatValue(val, userName = 'You', contactName = 'Them') {
  if (val === null || val === undefined) return '-'
  if (typeof val === 'boolean') return val ? 'Yes' : 'No'
  if (typeof val === 'number') {
    // Format percentages
    if (val >= 0 && val <= 100 && Number.isInteger(val)) return `${val}%`
    // Format decimals
    if (!Number.isInteger(val)) return val.toFixed(1)
  }
  if (typeof val === 'object') {
    // Handle ratio objects {you: X, them: Y}
    if (val.you !== undefined && val.them !== undefined) {
      return `${userName}: ${val.you}% / ${contactName}: ${val.them}%`
    }
    return JSON.stringify(val)
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
