import { createContext, useReducer, useCallback, useRef } from 'react'
import CircuitBreaker from '@/utils/circuitBreaker'
import { characterAPI } from '@/services/characterAPI'

/**
 * Character Context
 * Manages character selection, creation, and list state
 * ARCHITECTURAL FIX: Provides memoized fetch functions with circuit breaker
 */

export const CharacterContext = createContext()

const initialState = {
  characters: [],
  activeCharacterId: null,
  recentCharacters: [],
  isLoadingCharacters: false,
  isCreatingCharacter: false,
  characterError: null
}

const ACTIONS = {
  SET_LOADING: 'SET_LOADING',
  SET_CREATING: 'SET_CREATING',
  SET_CHARACTERS: 'SET_CHARACTERS',
  SET_ACTIVE_CHARACTER: 'SET_ACTIVE_CHARACTER',
  ADD_CHARACTER: 'ADD_CHARACTER',
  UPDATE_CHARACTER: 'UPDATE_CHARACTER',
  DELETE_CHARACTER: 'DELETE_CHARACTER',
  SET_RECENT_CHARACTERS: 'SET_RECENT_CHARACTERS',
  SET_ERROR: 'SET_ERROR',
  CLEAR_ERROR: 'CLEAR_ERROR'
}

function characterReducer(state, action) {
  switch (action.type) {
    case ACTIONS.SET_LOADING:
      return { ...state, isLoadingCharacters: action.payload }

    case ACTIONS.SET_CREATING:
      return { ...state, isCreatingCharacter: action.payload }

    case ACTIONS.SET_CHARACTERS:
      return { ...state, characters: action.payload }

    case ACTIONS.SET_ACTIVE_CHARACTER:
      return { ...state, activeCharacterId: action.payload }

    case ACTIONS.ADD_CHARACTER:
      return {
        ...state,
        characters: [action.payload, ...state.characters],
        activeCharacterId: action.payload.id
      }

    case ACTIONS.UPDATE_CHARACTER:
      return {
        ...state,
        characters: state.characters.map((char) =>
          char.id === action.payload.id
            ? { ...char, ...action.payload.updates }
            : char
        )
      }

    case ACTIONS.DELETE_CHARACTER:
      return {
        ...state,
        characters: state.characters.filter((char) => char.id !== action.payload),
        activeCharacterId:
          state.activeCharacterId === action.payload
            ? null
            : state.activeCharacterId
      }

    case ACTIONS.SET_RECENT_CHARACTERS:
      return { ...state, recentCharacters: action.payload }

    case ACTIONS.SET_ERROR:
      return { ...state, characterError: action.payload }

    case ACTIONS.CLEAR_ERROR:
      return { ...state, characterError: null }

    default:
      return state
  }
}

export function CharacterProvider({ children }) {
  const [state, dispatch] = useReducer(characterReducer, initialState)

  // Circuit breaker for API calls - prevents infinite retry loops
  const circuitBreakerRef = useRef(new CircuitBreaker({
    failureThreshold: 5,
    resetTimeout: 30000,
    name: 'CharacterAPI'
  }))

  const setLoading = useCallback((loading) => {
    dispatch({ type: ACTIONS.SET_LOADING, payload: loading })
  }, [])

  const setCreating = useCallback((creating) => {
    dispatch({ type: ACTIONS.SET_CREATING, payload: creating })
  }, [])

  const setCharacters = useCallback((characters) => {
    dispatch({ type: ACTIONS.SET_CHARACTERS, payload: characters })
  }, [])

  const setActiveCharacter = useCallback((characterId) => {
    dispatch({ type: ACTIONS.SET_ACTIVE_CHARACTER, payload: characterId })
  }, [])

  const addCharacter = useCallback((character) => {
    dispatch({ type: ACTIONS.ADD_CHARACTER, payload: character })
  }, [])

  const updateCharacter = useCallback((characterId, updates) => {
    dispatch({
      type: ACTIONS.UPDATE_CHARACTER,
      payload: { id: characterId, updates }
    })
  }, [])

  const deleteCharacter = useCallback((characterId) => {
    dispatch({ type: ACTIONS.DELETE_CHARACTER, payload: characterId })
  }, [])

  const setRecentCharacters = useCallback((characters) => {
    dispatch({ type: ACTIONS.SET_RECENT_CHARACTERS, payload: characters })
  }, [])

  const setError = useCallback((error) => {
    dispatch({ type: ACTIONS.SET_ERROR, payload: error })
  }, [])

  const clearError = useCallback(() => {
    dispatch({ type: ACTIONS.CLEAR_ERROR })
  }, [])

  // ARCHITECTURAL FIX: Memoized API wrapper functions with circuit breaker
  // These have STABLE references - won't cause infinite loops in useEffect
  const fetchCharacters = useCallback(async () => {
    setLoading(true)
    try {
      const characters = await circuitBreakerRef.current.execute(async () => {
        return await characterAPI.getCharacters()
      })
      setCharacters(characters)
      return characters
    } catch (error) {
      // Only log error once, don't spam console
      if (!error.circuitOpen) {
        console.error('[CharacterContext] Failed to fetch characters:', error.message)
      }
      setError(error.message)
      throw error
    } finally {
      setLoading(false)
    }
  }, [setLoading, setCharacters, setError])

  const fetchRecentCharacters = useCallback(async (limit = 5) => {
    try {
      const recent = await circuitBreakerRef.current.execute(async () => {
        return await characterAPI.getRecentCharacters(limit)
      })
      setRecentCharacters(recent)
      return recent
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[CharacterContext] Failed to fetch recent characters:', error.message)
      }
      setError(error.message)
      throw error
    }
  }, [setRecentCharacters, setError])

  const createCharacter = useCallback(async (characterData) => {
    setCreating(true)
    try {
      const newCharacter = await circuitBreakerRef.current.execute(async () => {
        return await characterAPI.createCharacter(characterData)
      })
      addCharacter(newCharacter)
      return newCharacter
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[CharacterContext] Failed to create character:', error.message)
      }
      setError(error.message)
      throw error
    } finally {
      setCreating(false)
    }
  }, [setCreating, addCharacter, setError])

  const updateCharacterData = useCallback(async (characterId, updates) => {
    try {
      const updated = await circuitBreakerRef.current.execute(async () => {
        return await characterAPI.updateCharacter(characterId, updates)
      })
      updateCharacter(characterId, updates)
      return updated
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[CharacterContext] Failed to update character:', error.message)
      }
      setError(error.message)
      throw error
    }
  }, [updateCharacter, setError])

  const deleteCharacterData = useCallback(async (characterId) => {
    try {
      await circuitBreakerRef.current.execute(async () => {
        return await characterAPI.deleteCharacter(characterId)
      })
      deleteCharacter(characterId)
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[CharacterContext] Failed to delete character:', error.message)
      }
      setError(error.message)
      throw error
    }
  }, [deleteCharacter, setError])

  const testResponse = useCallback(async (characterData, prompt) => {
    try {
      const response = await circuitBreakerRef.current.execute(async () => {
        return await characterAPI.testCharacterResponse(characterData, prompt)
      })
      return response
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[CharacterContext] Failed to test character response:', error.message)
      }
      setError(error.message)
      throw error
    }
  }, [setError])

  const value = {
    // State
    ...state,

    // Methods
    setLoading,
    setCreating,
    setCharacters,
    setActiveCharacter,
    addCharacter,
    updateCharacter,
    deleteCharacter,
    setRecentCharacters,
    setError,
    clearError,

    // ARCHITECTURAL FIX: Memoized API wrappers (stable references)
    fetchCharacters,
    fetchRecentCharacters,
    createCharacter: createCharacter,
    updateCharacterData,
    deleteCharacterData,
    testResponse
  }

  return (
    <CharacterContext.Provider value={value}>{children}</CharacterContext.Provider>
  )
}
