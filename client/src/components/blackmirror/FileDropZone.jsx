import { useRef, useState } from 'react'
import './FileDropZone.scss'

/**
 * FileDropZone Component
 * Reusable drag-drop zone for file uploads
 */

export default function FileDropZone({
  onFileSelect = () => {},
  acceptedFormats = '.json,.csv,.txt',
  maxSizemb = 50,
  label = 'Drop files here',
}) {
  const [isDragging, setIsDragging] = useState(false)
  const fileInputRef = useRef(null)

  // Handle file selection
  const handleFileSelect = (file) => {
    if (!file) return

    // Check file size
    const maxBytes = maxSizemb * 1024 * 1024
    if (file.size > maxBytes) {
      alert(`File size exceeds ${maxSizemb}MB limit`)
      return
    }

    onFileSelect(file)
  }

  // Handle drag events
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

    const file = e.dataTransfer.files[0]
    handleFileSelect(file)
  }

  // Handle file input change
  const handleInputChange = (e) => {
    const file = e.target.files?.[0]
    if (file) {
      handleFileSelect(file)
    }
  }

  return (
    <div className="file-drop-zone">
      <div
        className={`drop-area ${isDragging ? 'dragging' : ''}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
      >
        <div className="drop-icon">📁</div>
        <p className="drop-text">{label}</p>
        <p className="drop-hint">or click to select from computer</p>
        <p className="drop-info">Max {maxSizemb}MB</p>
      </div>

      {/* Hidden File Input */}
      <input
        ref={fileInputRef}
        type="file"
        accept={acceptedFormats}
        onChange={handleInputChange}
        className="hidden-file-input"
        aria-label="Upload file"
      />
    </div>
  )
}
