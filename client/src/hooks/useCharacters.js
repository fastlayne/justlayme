import { useContext } from 'react'
import { CharacterContext } from '@/contexts/CharacterContext'

/**
 * useCharacters Hook
 * Character management operations and state
 * ARCHITECTURAL FIX: Returns stable memoized functions from context
 * This prevents infinite loops in useEffect dependencies
 */

export function useCharacters() {
  const context = useContext(CharacterContext)

  if (!context) {
    throw new Error('useCharacters must be used within CharacterProvider')
  }

  return {
    // State
    characters: context.characters,
    activeCharacterId: context.activeCharacterId,
    activeCharacter: context.characters.find((c) => c.id === context.activeCharacterId),
    recentCharacters: context.recentCharacters,
    isLoading: context.isLoadingCharacters,
    isCreating: context.isCreatingCharacter,
    error: context.characterError,

    // Methods
    setLoading: context.setLoading,
    setCreating: context.setCreating,
    setCharacters: context.setCharacters,
    setActiveCharacter: context.setActiveCharacter,
    addCharacter: context.addCharacter,
    updateCharacter: context.updateCharacter,
    deleteCharacter: context.deleteCharacter,
    setError: context.setError,
    clearError: context.clearError,

    // ARCHITECTURAL FIX: Return stable memoized functions from context
    // These have stable references and won't cause infinite loops
    fetchCharacters: context.fetchCharacters,
    fetchRecentCharacters: context.fetchRecentCharacters,
    createCharacter: context.createCharacter,
    updateCharacterData: context.updateCharacterData,
    deleteCharacterData: context.deleteCharacterData,
    testResponse: context.testResponse,

    selectCharacter: (characterId) => {
      context.setActiveCharacter(characterId)
    }
  }
}
