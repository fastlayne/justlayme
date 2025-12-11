# Voice Settings Integration Guide

## Overview
Voice settings allow users to customize the audio output for AI character responses. This document outlines how voice settings are currently implemented and what would be needed for full integration.

## Current Implementation

### Frontend Components

#### 1. FormStepVoice Component
**Location**: `/home/fastl/JustLayMe-react/src/components/modals/FormStepVoice.jsx`

**Features**:
- Voice enable/disable toggle
- Voice type selection (Default, Warm, Deep, Bright, Soft)
- Pitch control (0.5x - 2.0x)
- Speed control (0.5x - 2.0x)
- Voice preview button

**Current State**: UI is complete and functional. Voice settings are stored in `formData.voiceSettings` object.

### Data Structure

Voice settings are stored as:
```javascript
{
  voiceSettings: {
    enabled: boolean,
    voiceId: string, // 'default' | 'warm' | 'deep' | 'bright' | 'soft'
    pitch: number,   // 0.5 to 2.0
    speed: number    // 0.5 to 2.0
  }
}
```

## Integration Requirements

### Backend Integration

#### 1. Character Creation
When a character is created, voice settings should be stored in the character configuration:

```javascript
// In character creation endpoint
const characterConfig = {
  name: formData.name,
  bio: formData.bio,
  personality: formData.personality,
  voiceSettings: formData.voiceSettings // Add this
};
```

#### 2. Text-to-Speech API
For actual voice output, integrate with a TTS service:

**Recommended Options**:
- ElevenLabs API (high quality, realistic voices)
- Google Cloud Text-to-Speech
- Amazon Polly
- OpenAI TTS

**Implementation Flow**:
1. User sends message
2. AI generates text response
3. If voice enabled: Send response text + voice settings to TTS API
4. Return both text and audio URL to frontend
5. Frontend plays audio automatically or on user click

#### 3. Voice Preview
The "Preview Voice" button should:
1. Generate sample text (e.g., "Hello, I'm [character name]")
2. Send to TTS API with current voice settings
3. Play the audio response

### Frontend Integration

#### 1. Update Character API Call
Modify the character creation to include voice settings:

**File**: `/home/fastl/JustLayMe-react/src/services/charactersAPI.js`

```javascript
createCharacter: async (characterData) => {
  return await apiClient.post('characters', {
    ...characterData,
    voiceSettings: characterData.voiceSettings || {
      enabled: false,
      voiceId: 'default',
      pitch: 1.0,
      speed: 1.0
    }
  })
}
```

#### 2. Message Display with Audio
Update message components to display audio player when available:

```javascript
// In MessageBubble component
{message.audioUrl && (
  <audio controls src={message.audioUrl} className="message-audio">
    Your browser does not support audio playback.
  </audio>
)}
```

#### 3. Voice Preview Handler
Implement the preview functionality in FormStepVoice:

```javascript
const handleVoicePreview = async () => {
  const previewText = `Hello, I'm ${formData.name || 'your AI character'}`;

  try {
    const response = await fetch('/api/tts/preview', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${localStorage.getItem('authToken')}`
      },
      body: JSON.stringify({
        text: previewText,
        voiceSettings: formData.voiceSettings
      })
    });

    const data = await response.json();
    const audio = new Audio(data.audioUrl);
    audio.play();
  } catch (error) {
    console.error('Voice preview failed:', error);
  }
};
```

### Backend API Endpoints Needed

#### 1. TTS Preview Endpoint
```
POST /api/tts/preview
Authorization: Bearer <token>
Body: {
  text: string,
  voiceSettings: {
    voiceId: string,
    pitch: number,
    speed: number
  }
}
Response: {
  audioUrl: string,
  duration: number
}
```

#### 2. Message with TTS
Enhance the chat endpoint to optionally include audio:

```
POST /api/chat
Body: {
  message: string,
  character: string,
  includeAudio: boolean
}
Response: {
  message: string,
  audioUrl?: string, // Only if includeAudio=true
  timestamp: string
}
```

## Current Limitations

1. **No TTS Integration**: Voice settings are captured but not used for actual audio generation
2. **Preview Not Functional**: The preview button exists but doesn't generate audio
3. **No Audio Storage**: Need to set up file storage for generated audio files
4. **No Voice Mapping**: Voice IDs (warm, deep, etc.) need to map to actual TTS voice models

## Implementation Priority

### Phase 1: Basic TTS (High Priority)
- [ ] Choose TTS provider (recommend ElevenLabs or OpenAI)
- [ ] Create TTS service wrapper
- [ ] Implement /api/tts/preview endpoint
- [ ] Connect preview button to backend

### Phase 2: Chat Integration (High Priority)
- [ ] Store voice settings with character data
- [ ] Generate audio for AI responses
- [ ] Add audio player to message bubbles
- [ ] Implement audio caching

### Phase 3: Advanced Features (Medium Priority)
- [ ] Voice cloning for custom voices
- [ ] Multiple language support
- [ ] Emotion-based voice modulation
- [ ] Audio streaming instead of full file generation

### Phase 4: Optimization (Low Priority)
- [ ] Audio compression
- [ ] CDN integration for audio files
- [ ] Lazy loading of audio
- [ ] Audio quality settings for bandwidth control

## Cost Considerations

**TTS API Pricing** (approximate):
- ElevenLabs: $0.18 per 1000 characters (high quality)
- OpenAI TTS: $0.015 per 1000 characters (good quality)
- Google Cloud: $0.000016 per character (basic quality)

**Storage**:
- Average audio file: 100KB - 500KB per message
- 1000 messages with audio: ~50MB - 250MB storage

**Recommendation**:
- Free tier users: No audio or limited to X messages/day
- Premium users: Unlimited audio with standard quality voice
- Premium+ users: High quality voices and voice cloning

## Testing Checklist

- [ ] Voice settings save correctly with character creation
- [ ] Voice settings load correctly when editing character
- [ ] Preview button generates and plays audio
- [ ] AI responses include audio when voice enabled
- [ ] Audio player controls work (play, pause, volume)
- [ ] Pitch and speed adjustments affect audio output
- [ ] Different voice types produce distinct audio
- [ ] Mobile devices can play audio correctly
- [ ] Audio doesn't auto-play (respect user preferences)
- [ ] Loading states during audio generation

## Support Resources

- ElevenLabs API Docs: https://docs.elevenlabs.io/
- OpenAI TTS Docs: https://platform.openai.com/docs/guides/text-to-speech
- Web Audio API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API

## Conclusion

Voice settings UI is **fully implemented and functional**. The main work needed is:
1. Backend TTS integration
2. Connecting preview button to TTS service
3. Adding audio generation to chat responses

The frontend is ready and waiting for backend TTS implementation.
