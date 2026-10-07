class EventApplicationState {
  const EventApplicationState({
    required this.exists,
    required this.status,
    required this.paymentStatus,
    required this.addressAccessStatus,
    required this.reservationStatus,
  });

  final bool exists;
  final String status;
  final String paymentStatus;
  final String addressAccessStatus;
  final String reservationStatus;

  factory EventApplicationState.none() {
    return const EventApplicationState(
      exists: false,
      status: '',
      paymentStatus: '',
      addressAccessStatus: 'locked',
      reservationStatus: 'none',
    );
  }

  factory EventApplicationState.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return EventApplicationState.none();
    }

    return EventApplicationState(
      exists: true,
      status: _normalize(data['status']),
      paymentStatus: _normalize(data['paymentStatus']),
      addressAccessStatus: _normalize(data['addressAccessStatus'] ?? 'locked'),
      reservationStatus: _normalize(data['reservationStatus'] ?? 'none'),
    );
  }

  bool get isPending => status == 'pending';

  bool get isRejected => status == 'rejected';

  bool get isWithdrawn => status == 'withdrawn';

  bool get isAcceptedWaitingRoster => status == 'accepted_waiting_roster';

  bool get isAcceptedPaymentPending => status == 'accepted_payment_pending';

  bool get isPaymentProcessing =>
      status == 'payment_processing' || paymentStatus == 'payment_processing';

  bool get isPaid =>
      paymentStatus == 'paid' ||
      paymentStatus == 'completed' ||
      (status == 'paid' && paymentStatus != 'not_required');

  bool get isFreeMember =>
      addressAccessStatus == 'unlocked' &&
      paymentStatus == 'not_required' &&
      status != 'pending' &&
      status != 'rejected' &&
      status != 'withdrawn' &&
      status != 'removed' &&
      status != 'left' &&
      status != 'cancelled' &&
      status != 'refund_pending' &&
      status != 'refunded';

  bool get isAddressUnlocked =>
      addressAccessStatus == 'unlocked' && (isPaid || isFreeMember);

  bool get isStarted => status == 'started';

  bool get isCompleted => status == 'completed';

  bool get isCancelled => status == 'cancelled';

  bool get isRefundPending =>
      status == 'refund_pending' || paymentStatus == 'refund_pending';

  bool get isRefunded => status == 'refunded' || paymentStatus == 'refunded';

  bool get isDisputeReview => status == 'dispute_review';

  bool get blocksNewApplication {
    return exists && !isRejected;
  }

  String get userLabel => userLabelFor('tr');

  String userLabelFor(String languageCode) {
    String text({required String tr, required String en, required String de}) {
      switch (languageCode.trim().toLowerCase()) {
        case 'en':
          return en;
        case 'de':
          return de;
        default:
          return tr;
      }
    }

    if (!exists) return '';
    if (isPending) {
      return text(
        tr: 'Etkinlik sahibinin kararı bekleniyor',
        en: 'Waiting for the event owner\'s decision',
        de: 'Entscheidung des Veranstalters ausstehend',
      );
    }
    if (isRejected) {
      return text(
        tr: 'Başvuru reddedildi',
        en: 'Application rejected',
        de: 'Bewerbung abgelehnt',
      );
    }
    if (isWithdrawn) {
      return text(
        tr: 'Başvuru geri çekildi',
        en: 'Application withdrawn',
        de: 'Bewerbung zurückgezogen',
      );
    }
    if (isAcceptedWaitingRoster) {
      return text(
        tr: 'Başvuru kabul edildi — kadronun tamamlanması bekleniyor',
        en: 'Application accepted — waiting for the roster to be completed',
        de: 'Bewerbung angenommen — Kadervervollständigung ausstehend',
      );
    }
    if (isAcceptedPaymentPending) {
      return text(
        tr: 'Etkinlik durumu güncelleniyor',
        en: 'Event status is updating',
        de: 'Veranstaltungsstatus wird aktualisiert',
      );
    }
    if (isPaymentProcessing) {
      return text(
        tr: 'Etkinlik durumu güncelleniyor',
        en: 'Event status is updating',
        de: 'Veranstaltungsstatus wird aktualisiert',
      );
    }
    if (isFreeMember) {
      return text(
        tr: 'Kadroya alındın — adres ve sohbet açıldı',
        en: 'You joined the roster — address and chat are open',
        de: 'Du bist im Kader — Adresse und Chat sind offen',
      );
    }
    if (isAddressUnlocked) {
      return text(
        tr: 'Adres açıldı',
        en: 'Address unlocked',
        de: 'Adresse freigeschaltet',
      );
    }
    if (isPaid) {
      return text(
        tr: 'Etkinlik durumu güncelleniyor',
        en: 'Event status is updating',
        de: 'Veranstaltungsstatus wird aktualisiert',
      );
    }
    if (isStarted) {
      return text(
        tr: 'Etkinlik başladı',
        en: 'Event started',
        de: 'Veranstaltung gestartet',
      );
    }
    if (isCompleted) {
      return text(
        tr: 'Etkinlik tamamlandı',
        en: 'Event completed',
        de: 'Veranstaltung abgeschlossen',
      );
    }
    if (isRefundPending) {
      return text(
        tr: 'Etkinlik durumu güncelleniyor',
        en: 'Event status is updating',
        de: 'Veranstaltungsstatus wird aktualisiert',
      );
    }
    if (isRefunded) {
      return text(
        tr: 'Etkinlik durumu güncelleniyor',
        en: 'Event status is updating',
        de: 'Veranstaltungsstatus wird aktualisiert',
      );
    }
    if (isDisputeReview) {
      return text(
        tr: 'Anlaşmazlık incelemede',
        en: 'Dispute under review',
        de: 'Streitfall wird geprüft',
      );
    }
    if (isCancelled) {
      return text(tr: 'İptal edildi', en: 'Cancelled', de: 'Abgesagt');
    }
    return text(
      tr: 'Başvuru durumu güncelleniyor',
      en: 'Application status is updating',
      de: 'Bewerbungsstatus wird aktualisiert',
    );
  }

  static String _normalize(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }
}
