import { useState } from 'react'
import { useNotification } from '@/hooks/useNotification'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'
import './ExportButton.scss'

/**
 * ExportButton Component
 * Export analysis results in multiple formats (PDF, CSV, JSON)
 */

const EXPORT_FORMATS = [
  { value: 'pdf', label: '📄 PDF Report', description: 'Full report with charts' },
  { value: 'csv', label: '📊 CSV Data', description: 'Raw metrics data' },
  { value: 'json', label: '{ } JSON', description: 'Complete analysis JSON' },
]

export default function ExportButton({ results = {} }) {
  const [showMenu, setShowMenu] = useState(false)
  const [isExporting, setIsExporting] = useState(false)
  const notification = useNotification()

  /**
   * Export results as PDF with formatted layout
   */
  const exportAsPDF = () => {
    const doc = new jsPDF()
    const timestamp = new Date().toLocaleDateString()

    // Title
    doc.setFontSize(20)
    doc.text('The Grey Mirror Analysis Report', 20, 20)

    // Metadata
    doc.setFontSize(10)
    doc.text(`Generated: ${timestamp}`, 20, 30)
    doc.text(`Analysis ID: ${results.analysisId || 'N/A'}`, 20, 35)

    // Summary section
    doc.setFontSize(14)
    doc.text('Summary', 20, 50)
    doc.setFontSize(10)

    const summaryData = [
      ['Overall Health Score', results.healthScore || 'N/A'],
      ['Messages Analyzed', results.messageCount || '0'],
      ['Analysis Date', results.date || timestamp],
      ['Upload Method', results.uploadMethod || 'N/A']
    ]

    doc.autoTable({
      startY: 55,
      head: [['Metric', 'Value']],
      body: summaryData,
      theme: 'grid',
      headStyles: { fillColor: [66, 139, 202] }
    })

    // Metrics section
    if (results.metrics && Object.keys(results.metrics).length > 0) {
      doc.setFontSize(14)
      doc.text('Detailed Metrics', 20, doc.lastAutoTable.finalY + 15)

      const metricsData = Object.entries(results.metrics).map(([key, value]) => [
        key.replace(/([A-Z])/g, ' $1').trim(),
        typeof value === 'object' ? JSON.stringify(value) : String(value)
      ])

      doc.autoTable({
        startY: doc.lastAutoTable.finalY + 20,
        head: [['Metric', 'Value']],
        body: metricsData,
        theme: 'striped',
        headStyles: { fillColor: [66, 139, 202] }
      })
    }

    // Insights section
    if (results.insights && Array.isArray(results.insights)) {
      doc.setFontSize(14)
      doc.text('Key Insights', 20, doc.lastAutoTable.finalY + 15)
      doc.setFontSize(10)

      results.insights.forEach((insight, index) => {
        const yPos = doc.lastAutoTable.finalY + 25 + (index * 10)
        doc.text(`${index + 1}. ${insight}`, 25, yPos)
      })
    }

    // Footer
    const pageCount = doc.internal.getNumberOfPages()
    for (let i = 1; i <= pageCount; i++) {
      doc.setPage(i)
      doc.setFontSize(8)
      doc.text(
        `Page ${i} of ${pageCount} - JustLayMe The Grey Mirror Report`,
        doc.internal.pageSize.width / 2,
        doc.internal.pageSize.height - 10,
        { align: 'center' }
      )
    }

    // Download
    doc.save(`black-mirror-analysis-${timestamp.replace(/\//g, '-')}.pdf`)
  }

  /**
   * Export results as CSV
   */
  const exportAsCSV = () => {
    const timestamp = new Date().toISOString()
    let csvContent = 'Metric,Value\n'

    // Add summary data
    csvContent += `"Overall Health Score","${results.healthScore || 'N/A'}"\n`
    csvContent += `"Messages Analyzed","${results.messageCount || '0'}"\n`
    csvContent += `"Analysis Date","${results.date || timestamp}"\n`
    csvContent += `"Upload Method","${results.uploadMethod || 'N/A'}"\n`
    csvContent += '\n'

    // Add detailed metrics
    if (results.metrics && Object.keys(results.metrics).length > 0) {
      csvContent += '"Detailed Metrics"\n'
      Object.entries(results.metrics).forEach(([key, value]) => {
        const metricName = key.replace(/([A-Z])/g, ' $1').trim()
        const metricValue = typeof value === 'object'
          ? JSON.stringify(value).replace(/"/g, '""')
          : String(value).replace(/"/g, '""')
        csvContent += `"${metricName}","${metricValue}"\n`
      })
    }

    // Create blob and download
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `black-mirror-analysis-${new Date().toISOString().split('T')[0]}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  /**
   * Export results as JSON
   */
  const exportAsJSON = () => {
    const timestamp = new Date().toISOString()
    const exportData = {
      exportedAt: timestamp,
      analysisId: results.analysisId || `analysis_${Date.now()}`,
      ...results
    }

    const blob = new Blob([JSON.stringify(exportData, null, 2)], {
      type: 'application/json'
    })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `black-mirror-analysis-${new Date().toISOString().split('T')[0]}.json`
    link.click()
    URL.revokeObjectURL(url)
  }

  /**
   * Handle export based on selected format
   */
  const handleExport = async (format) => {
    setIsExporting(true)
    try {
      switch (format) {
        case 'pdf':
          exportAsPDF()
          break
        case 'csv':
          exportAsCSV()
          break
        case 'json':
          exportAsJSON()
          break
        default:
          throw new Error(`Unknown format: ${format}`)
      }

      notification.success(`Successfully exported as ${format.toUpperCase()}!`)
      setShowMenu(false)
    } catch (error) {
      console.error('Export failed:', error)
      notification.error(`Export failed: ${error.message}`)
    } finally {
      setIsExporting(false)
    }
  }

  return (
    <div className="export-button-wrapper">
      <button
        className="btn btn-primary"
        onClick={() => setShowMenu(!showMenu)}
        disabled={isExporting}
      >
        {isExporting ? '⏳ Exporting...' : '⬇️ Export Results'}
      </button>

      {showMenu && (
        <div className="export-menu">
          {EXPORT_FORMATS.map((format) => (
            <button
              key={format.value}
              className="export-option"
              onClick={() => handleExport(format.value)}
              disabled={isExporting}
            >
              <div className="option-label">{format.label}</div>
              <div className="option-description">{format.description}</div>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
