/**
 * Queue and retry state policy for interrupted automatic verification analysis.
 * Ensures submissions stuck in "processing" or failed transiently are retried
 * with bounded backoff and escalated to manual review rather than hanging.
 */

export const DEFAULT_PROCESSING_STALE_MS = 10 * 60 * 1000;
export const DEFAULT_MAX_ANALYSIS_ATTEMPTS = 3;
export const DEFAULT_RETRY_BASE_DELAY_MS = 60 * 1000;

export type VerificationQueueAction =
  "skip" | "retry" | "escalate_manual_review";

export interface VerificationQueueSnapshot {
  status: string;
  automaticCheckStatus: string;
  attemptCount: number;
  processingStartedAtMs: number | null;
  lastAttemptAtMs: number | null;
  nowMs: number;
  staleProcessingMs?: number;
  maxAttempts?: number;
  retryBaseDelayMs?: number;
}

export interface VerificationQueueDecision {
  action: VerificationQueueAction;
  reasonCode: string;
  nextAttemptCount: number;
}

/**
 * Decides whether a verification request should be skipped, safely retried, or
 * escalated to manual review after exhausting automatic retries.
 * @param {VerificationQueueSnapshot} input Current request queue state.
 * @return {VerificationQueueDecision} Bounded queue action.
 */
export function evaluateVerificationQueueRecovery(
  input: VerificationQueueSnapshot,
): VerificationQueueDecision {
  const status = input.status.trim().toLowerCase();
  const checkStatus = input.automaticCheckStatus.trim().toLowerCase();
  const attempts = Number.isFinite(input.attemptCount) &&
    input.attemptCount > 0 ?
    Math.trunc(input.attemptCount) :
    0;
  const staleMs = input.staleProcessingMs ?? DEFAULT_PROCESSING_STALE_MS;
  const maxAttempts = input.maxAttempts ?? DEFAULT_MAX_ANALYSIS_ATTEMPTS;
  const baseDelayMs = input.retryBaseDelayMs ?? DEFAULT_RETRY_BASE_DELAY_MS;

  if (status !== "pending") {
    return {
      action: "skip",
      reasonCode: "already_decided",
      nextAttemptCount: attempts,
    };
  }

  if (
    checkStatus === "passed" ||
    checkStatus === "needs_review" ||
    checkStatus === "failed"
  ) {
    return {
      action: "skip",
      reasonCode: "analysis_already_finished",
      nextAttemptCount: attempts,
    };
  }

  if (checkStatus === "processing") {
    const startedAt = input.processingStartedAtMs;
    if (startedAt != null && input.nowMs - startedAt < staleMs) {
      return {
        action: "skip",
        reasonCode: "processing_active",
        nextAttemptCount: attempts,
      };
    }

    if (attempts >= maxAttempts) {
      return {
        action: "escalate_manual_review",
        reasonCode: "analysis_retries_exhausted",
        nextAttemptCount: attempts,
      };
    }

    return {
      action: "retry",
      reasonCode: "stale_processing_recovered",
      nextAttemptCount: attempts + 1,
    };
  }

  if (checkStatus === "pending" || checkStatus === "") {
    if (attempts >= maxAttempts) {
      return {
        action: "escalate_manual_review",
        reasonCode: "analysis_retries_exhausted",
        nextAttemptCount: attempts,
      };
    }

    const backoffMs = attempts > 0 ?
      baseDelayMs * Math.pow(2, attempts - 1) :
      0;
    if (
      attempts > 0 &&
      input.lastAttemptAtMs != null &&
      input.nowMs - input.lastAttemptAtMs < backoffMs
    ) {
      return {
        action: "skip",
        reasonCode: "retry_backoff_active",
        nextAttemptCount: attempts,
      };
    }

    return {
      action: "retry",
      reasonCode: "pending_analysis_ready",
      nextAttemptCount: attempts + 1,
    };
  }

  return {
    action: "escalate_manual_review",
    reasonCode: "unknown_analysis_state",
    nextAttemptCount: attempts,
  };
}
