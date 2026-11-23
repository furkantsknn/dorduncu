export interface VerificationObjectVersion {
  field: string;
  path: string;
  generation: string;
  missing?: boolean;
}

/**
 * Builds the only safe delete options for a versioned Storage object.
 * @param {string} generation Immutable object generation.
 * @return {{ignoreNotFound: boolean, ifGenerationMatch: string}} Options.
 */
export function exactGenerationDeleteOptions(generation: string): {
  ignoreNotFound: boolean;
  ifGenerationMatch: string;
} {
  const normalized = generation.trim();
  if (!normalized) {
    throw new Error("Storage generation is required for deletion.");
  }
  return {ignoreNotFound: true, ifGenerationMatch: normalized};
}

export interface VerificationCleanupPlan {
  requestId: string;
  submissionId: string;
  operationId: string;
  decisionVersion: string;
  decisionStatus: string;
  retentionStartedAtMillis: number;
  objects: VerificationObjectVersion[];
}

export interface VerificationCleanupDependencies {
  prepare: () => Promise<VerificationCleanupPlan | null>;
  deleteObject: (object: VerificationObjectVersion) => Promise<void>;
  complete: (plan: VerificationCleanupPlan) => Promise<boolean>;
  failed: (plan: VerificationCleanupPlan, error: unknown) => Promise<void>;
}

/**
 * Runs one idempotent cleanup attempt. Firestore preparation/completion must
 * compare the immutable submission and operation IDs atomically.
 * @param {VerificationCleanupDependencies} dependencies External operations.
 * @return {Promise<boolean>} True only after the matching request is finalized.
 */
export async function runVerificationCleanupAttempt(
  dependencies: VerificationCleanupDependencies,
): Promise<boolean> {
  const plan = await dependencies.prepare();
  if (!plan) {
    return false;
  }

  try {
    for (const object of plan.objects) {
      await dependencies.deleteObject(object);
    }
  } catch (error) {
    await dependencies.failed(plan, error);
    return false;
  }

  return dependencies.complete(plan);
}

export interface VerificationCleanupPage<T> {
  records: T[];
  lastId: string | null;
}

export interface VerificationCleanupScanResult {
  scanned: number;
  succeeded: number;
  failed: number;
}

/**
 * Scans immutable document-ID pages. Individual record failures do not block
 * later records and the cursor always advances to the returned last ID.
 * @param {Function} fetchPage Page fetcher.
 * @param {Function} processRecord Record processor.
 * @return {Promise<VerificationCleanupScanResult>} Aggregate result.
 */
export async function scanVerificationCleanupPages<T>(
  fetchPage: (
    cursor: string | null,
  ) => Promise<VerificationCleanupPage<T>>,
  processRecord: (record: T) => Promise<boolean>,
): Promise<VerificationCleanupScanResult> {
  let cursor: string | null = null;
  let scanned = 0;
  let succeeded = 0;
  let failed = 0;

  let finished = false;
  while (!finished) {
    const page = await fetchPage(cursor);
    if (page.records.length === 0) {
      finished = true;
      continue;
    }

    for (const record of page.records) {
      scanned += 1;
      try {
        if (await processRecord(record)) {
          succeeded += 1;
        }
      } catch {
        failed += 1;
      }
    }

    if (!page.lastId || page.lastId === cursor) {
      throw new Error("Verification cleanup cursor did not advance.");
    }
    cursor = page.lastId;
  }

  return {scanned, succeeded, failed};
}
