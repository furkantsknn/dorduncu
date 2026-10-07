/**
 * Compatibility exports for the canonical event-payment lifecycle projector.
 *
 * Batch 10 consolidated payment projection into eventPaymentLifecycle.ts so
 * there is only one source of truth for event/session/application state.
 */
export {
  applyEventPaymentLifecycleProjection,
  readEventPaymentLifecycleContext,
} from "./eventPaymentLifecycle";
export type {
  PaymentLifecycleContext,
} from "./eventPaymentLifecycle";
