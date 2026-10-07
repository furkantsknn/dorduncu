export type VerificationCheckStatus =
  "passed" | "failed" | "unavailable";

export interface VerificationCheck {
  status: VerificationCheckStatus;
  reasonCode: string;
}

export interface VerificationDecision {
  status: "pending" | "rejected";
  automaticCheckStatus: "passed" | "needs_review" | "failed";
  reasonCode: string;
  decisionSource: "automatic";
  userStatus: "pending" | "rejected";
}

/**
 * Missing or unmatched identity text stays uncertain.
 * It does not reject the application by itself.
 * @param {{readable: boolean, termsMatched: boolean}} input OCR outcome.
 * @return {VerificationCheck} Check to store.
 */
export function classifyIdentityTerms(input: {
  readable: boolean;
  termsMatched: boolean;
}): VerificationCheck {
  if (!input.readable) {
    return {
      status: "unavailable",
      reasonCode: "identity_text_unreadable",
    };
  }

  if (!input.termsMatched) {
    return {
      status: "unavailable",
      reasonCode: "identity_terms_unmatched",
    };
  }

  return {
    status: "passed",
    reasonCode: "identity_type_match",
  };
}

/**
 * Turns check results into a stored decision.
 * Unavailable OCR or API results stay pending. Only an explicit
 * failed check rejects. Passing checks do not approve.
 * @param {VerificationCheck[]} checks Completed checks.
 * @return {VerificationDecision} Decision to store.
 */
export function decideVerification(
  checks: VerificationCheck[],
): VerificationDecision {
  const failed = checks.find((check) => check.status === "failed");

  if (failed) {
    return {
      status: "rejected",
      automaticCheckStatus: "failed",
      reasonCode: failed.reasonCode,
      decisionSource: "automatic",
      userStatus: "rejected",
    };
  }

  const unavailable = checks.find(
    (check) => check.status === "unavailable",
  );

  if (unavailable) {
    return {
      status: "pending",
      automaticCheckStatus: "needs_review",
      reasonCode: unavailable.reasonCode,
      decisionSource: "automatic",
      userStatus: "pending",
    };
  }

  return {
    status: "pending",
    automaticCheckStatus: "passed",
    reasonCode: "",
    decisionSource: "automatic",
    userStatus: "pending",
  };
}
