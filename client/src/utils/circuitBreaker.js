/**
 * Circuit Breaker Pattern Implementation
 * Prevents cascading failures by stopping retries after consecutive failures
 *
 * States:
 * - CLOSED: Normal operation, requests pass through
 * - OPEN: Too many failures, requests fail fast
 * - HALF_OPEN: Testing if service recovered, allow one request
 */

const CIRCUIT_STATE = {
  CLOSED: 'CLOSED',
  OPEN: 'OPEN',
  HALF_OPEN: 'HALF_OPEN'
}

class CircuitBreaker {
  constructor({
    failureThreshold = 5,        // Open circuit after N consecutive failures
    resetTimeout = 30000,         // Try again after 30s
    monitoringPeriod = 60000,     // Track failures in 60s window
    name = 'CircuitBreaker'       // For logging
  } = {}) {
    this.failureThreshold = failureThreshold
    this.resetTimeout = resetTimeout
    this.monitoringPeriod = monitoringPeriod
    this.name = name

    this.state = CIRCUIT_STATE.CLOSED
    this.failureCount = 0
    this.lastFailureTime = null
    this.nextAttemptTime = null
    this.consecutiveSuccesses = 0
  }

  /**
   * Execute a function with circuit breaker protection
   * @param {Function} fn - Async function to execute
   * @returns {Promise} - Result of function or error
   */
  async execute(fn) {
    if (this.state === CIRCUIT_STATE.OPEN) {
      // Check if enough time has passed to try again
      if (Date.now() >= this.nextAttemptTime) {
        console.log(`[${this.name}] Circuit entering HALF_OPEN state (testing recovery)`)
        this.state = CIRCUIT_STATE.HALF_OPEN
      } else {
        const waitSeconds = Math.ceil((this.nextAttemptTime - Date.now()) / 1000)
        const error = new Error(`Circuit breaker is OPEN. Service unavailable. Retry in ${waitSeconds}s`)
        error.circuitOpen = true
        throw error
      }
    }

    try {
      const result = await fn()
      this.onSuccess()
      return result
    } catch (error) {
      this.onFailure()
      throw error
    }
  }

  onSuccess() {
    this.consecutiveSuccesses++

    if (this.state === CIRCUIT_STATE.HALF_OPEN) {
      // Recovery confirmed, close circuit
      console.log(`[${this.name}] Circuit CLOSED (service recovered)`)
      this.state = CIRCUIT_STATE.CLOSED
      this.failureCount = 0
      this.lastFailureTime = null
    } else if (this.state === CIRCUIT_STATE.CLOSED && this.failureCount > 0) {
      // Gradual recovery in closed state
      this.failureCount = Math.max(0, this.failureCount - 1)
    }
  }

  onFailure() {
    this.failureCount++
    this.lastFailureTime = Date.now()
    this.consecutiveSuccesses = 0

    if (this.state === CIRCUIT_STATE.HALF_OPEN) {
      // Recovery test failed, open circuit again
      console.error(`[${this.name}] Circuit OPEN (recovery failed, ${this.failureCount} consecutive failures)`)
      this.state = CIRCUIT_STATE.OPEN
      this.nextAttemptTime = Date.now() + this.resetTimeout
    } else if (this.failureCount >= this.failureThreshold) {
      // Threshold exceeded, open circuit
      console.error(`[${this.name}] Circuit OPEN (threshold exceeded: ${this.failureCount}/${this.failureThreshold})`)
      this.state = CIRCUIT_STATE.OPEN
      this.nextAttemptTime = Date.now() + this.resetTimeout
    }
  }

  /**
   * Reset the circuit breaker to initial state
   */
  reset() {
    console.log(`[${this.name}] Circuit manually reset`)
    this.state = CIRCUIT_STATE.CLOSED
    this.failureCount = 0
    this.lastFailureTime = null
    this.nextAttemptTime = null
    this.consecutiveSuccesses = 0
  }

  /**
   * Get current circuit status
   */
  getStatus() {
    return {
      state: this.state,
      failureCount: this.failureCount,
      consecutiveSuccesses: this.consecutiveSuccesses,
      isOpen: this.state === CIRCUIT_STATE.OPEN,
      nextAttemptTime: this.nextAttemptTime
    }
  }
}

/**
 * Exponential backoff retry logic with max attempts
 * @param {Function} fn - Async function to retry
 * @param {Object} options - Retry configuration
 * @returns {Promise} - Result or throws after max retries
 */
export async function retryWithBackoff(fn, {
  maxRetries = 3,
  initialDelay = 1000,
  maxDelay = 10000,
  factor = 2,
  onRetry = null
} = {}) {
  let lastError

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error

      // Don't retry if circuit is open
      if (error.circuitOpen) {
        throw error
      }

      // Don't retry on last attempt
      if (attempt === maxRetries) {
        break
      }

      // Calculate delay with exponential backoff
      const delay = Math.min(initialDelay * Math.pow(factor, attempt), maxDelay)

      if (onRetry) {
        onRetry(attempt + 1, delay, error)
      }

      console.warn(`Retry attempt ${attempt + 1}/${maxRetries} after ${delay}ms`, error.message)

      // Wait before retrying
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }

  throw lastError
}

export default CircuitBreaker
