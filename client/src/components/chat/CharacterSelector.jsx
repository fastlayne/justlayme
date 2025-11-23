import { useMemo, useCallback } from 'react'
import './CharacterSelector.scss'

/**
 * CharacterSelector Component
 * Displays active character and allows switching between characters
 * Shows character name, bio, and avatar in sidebar
 */

export default function CharacterSelector({
  characters = [],
  activeCharacterId = null,
  onSelect = () => {},
}) {
  // Find active character
  const activeCharacter = useMemo(
    () => characters.find((c) => c.id === activeCharacterId) || characters[0],
    [characters, activeCharacterId]
  )

  // Callback to handle character selection
  const handleSelect = useCallback(
    (characterId) => {
      onSelect(characterId)
    },
    [onSelect]
  )

  // Show empty state if no characters
  if (!characters || characters.length === 0) {
    return (
      <div className="character-selector empty">
        <p>No characters available</p>
      </div>
    )
  }

  return (
    <div className="character-selector">
      {/* Active Character Display */}
      {activeCharacter && (
        <div className="active-character">
          <div className="character-avatar">
            {activeCharacter.avatar ? (
              <img src={activeCharacter.avatar} alt={activeCharacter.name} />
            ) : (
              <div className="avatar-placeholder">{activeCharacter.name?.charAt(0) || 'C'}</div>
            )}
          </div>
          <div className="character-info">
            <h3 className="character-name">{activeCharacter.name}</h3>
            <p className="character-bio">{activeCharacter.bio || 'No description'}</p>
          </div>
        </div>
      )}

      {/* Character Switch Dropdown */}
      {characters.length > 1 && (
        <div className="character-list">
          <div className="character-list-header">
            <span>Other Characters</span>
          </div>
          <div className="character-options">
            {characters
              .filter((c) => c.id !== activeCharacterId)
              .map((character) => (
                <button
                  key={character.id}
                  className="character-option"
                  onClick={() => handleSelect(character.id)}
                  title={character.name}
                >
                  <div className="option-avatar">
                    {character.avatar ? (
                      <img src={character.avatar} alt={character.name} />
                    ) : (
                      <div className="avatar-placeholder">{character.name?.charAt(0) || 'C'}</div>
                    )}
                  </div>
                  <div className="option-info">
                    <div className="option-name">{character.name}</div>
                    <div className="option-bio">{character.bio || 'No description'}</div>
                  </div>
                </button>
              ))}
          </div>
        </div>
      )}
    </div>
  )
}
