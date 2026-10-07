# EVENT PAYMENT CANONICAL FLOW

event roster completed
→ paymentSessions/{eventId}
→ organizer calls startPayment
→ server validates event/session/deadline/amount
→ commercial operation reservation
→ event_payment_intents/{operationId}
→ EventPaymentProvider.createPaymentIntent()
→ HTTPS checkoutUrl
→ Flutter opens external provider
→ verified provider webhook is the financial truth
→ client callback never means paid

Next:
verified webhook
→ paymentSessions
→ events
→ accepted applications
→ address/chat authorization
→ refund/dispute/payout lifecycle
