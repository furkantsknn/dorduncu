enum VerificationDisplayKind {
  none,
  pending,
  approved,
  rejected,
  revision,
  expired,
  unknown,
}

class VerificationDisplay {
  const VerificationDisplay({required this.kind, this.reason = ''});

  final VerificationDisplayKind kind;
  final String reason;

  bool get showRejected => kind == VerificationDisplayKind.rejected;

  bool get allowReapply =>
      kind == VerificationDisplayKind.rejected ||
      kind == VerificationDisplayKind.unknown ||
      kind == VerificationDisplayKind.revision ||
      kind == VerificationDisplayKind.expired ||
      kind == VerificationDisplayKind.none;
}

String _text({
  required String languageCode,
  required String tr,
  required String en,
  required String de,
}) {
  switch (languageCode.toLowerCase()) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}

String verificationStatusTitle({
  required VerificationDisplayKind kind,
  required String languageCode,
}) {
  switch (kind) {
    case VerificationDisplayKind.approved:
      return _text(
        languageCode: languageCode,
        tr: 'Onaylandı',
        en: 'Approved',
        de: 'Genehmigt',
      );
    case VerificationDisplayKind.pending:
      return _text(
        languageCode: languageCode,
        tr: 'İnceleme bekliyor',
        en: 'Waiting for review',
        de: 'Prüfung ausstehend',
      );
    case VerificationDisplayKind.rejected:
      return _text(
        languageCode: languageCode,
        tr: 'Reddedildi',
        en: 'Rejected',
        de: 'Abgelehnt',
      );
    case VerificationDisplayKind.revision:
      return _text(
        languageCode: languageCode,
        tr: 'Düzeltme bekleniyor',
        en: 'Correction needed',
        de: 'Korrektur erforderlich',
      );
    case VerificationDisplayKind.expired:
      return _text(
        languageCode: languageCode,
        tr: 'Süresi doldu',
        en: 'Expired',
        de: 'Abgelaufen',
      );
    case VerificationDisplayKind.unknown:
      return _text(
        languageCode: languageCode,
        tr: 'Sonuç doğrulanamadı',
        en: 'Result could not be confirmed',
        de: 'Ergebnis nicht bestätigt',
      );
    case VerificationDisplayKind.none:
      return _text(
        languageCode: languageCode,
        tr: 'Başvuru yok',
        en: 'No application',
        de: 'Kein Antrag',
      );
  }
}

String verificationReasonText({
  required String reasonCode,
  required String languageCode,
}) {
  switch (reasonCode) {
    case 'selfie_no_face':
    case 'selfie_multiple_faces':
    case 'selfie_unsuitable':
      return _text(
        languageCode: languageCode,
        tr: 'Uygun selfie ile yeniden başvur.',
        en: 'Apply again with a suitable selfie.',
        de: 'Stelle den Antrag mit einem passenden Selfie erneut.',
      );
    case 'liveness_failed':
    case 'photo_quality_failed':
      return _text(
        languageCode: languageCode,
        tr: 'Aydınlık bir ortamda net belge ve canlı selfie ile yeniden başvur.',
        en: 'Apply again with a clear document and live selfie in good lighting.',
        de: 'Stelle den Antrag bei gutem Licht mit klarem Dokument und Live-Selfie erneut.',
      );
    case 'face_mismatch':
      return _text(
        languageCode: languageCode,
        tr: 'Kimlik fotoğrafı ile selfie eşleşemedi. Net fotoğraflarla yeniden başvurabilir veya inceleme talep edebilirsin.',
        en: 'The ID photo and selfie could not be matched. You can apply again with clearer photos or request a review.',
        de: 'Ausweisfoto und Selfie konnten nicht zugeordnet werden. Du kannst den Antrag mit klareren Fotos erneut stellen oder eine Prüfung anfordern.',
      );
    case 'document_authenticity_failed':
      return _text(
        languageCode: languageCode,
        tr: 'Kimlik belgesi doğrulanamadı. Orijinal ve net bir belge fotoğrafıyla yeniden başvurabilirsin.',
        en: 'The identity document could not be verified. You can apply again with a clear photo of the original document.',
        de: 'Das Ausweisdokument konnte nicht bestätigt werden. Du kannst den Antrag mit einem klaren Foto des Originaldokuments erneut stellen.',
      );
    case 'identity_already_used':
      return _text(
        languageCode: languageCode,
        tr: 'Bu kimlik başka bir hesapta kayıtlı. Farklı bir belgeyle yeniden başvurabilirsin.',
        en: 'This identity is already registered on another account. You can apply again with a different document.',
        de: 'Dieser Ausweis ist bereits einem anderen Konto zugeordnet. Du kannst den Antrag mit einem anderen Dokument erneut stellen.',
      );
    case 'admin_decision':
      return _text(
        languageCode: languageCode,
        tr: 'Başvurun incelendi ve reddedildi.',
        en: 'Your application was reviewed and rejected.',
        de: 'Dein Antrag wurde geprüft und abgelehnt.',
      );
    default:
      return '';
  }
}

VerificationDisplay presentVerificationStatus({
  required String status,
  required String reasonCode,
  required String decisionReason,
  required String decisionSource,
  required String languageCode,
}) {
  switch (status) {
    case 'approved':
      return const VerificationDisplay(kind: VerificationDisplayKind.approved);
    case 'pending':
    case 'needs_review':
      return const VerificationDisplay(kind: VerificationDisplayKind.pending);
    case 'revision':
      return VerificationDisplay(
        kind: VerificationDisplayKind.revision,
        reason: decisionReason.trim(),
      );
    case 'expired':
      return const VerificationDisplay(kind: VerificationDisplayKind.expired);
    case 'rejected':
      final String adminReason = decisionReason.trim();
      if (decisionSource == 'admin' && adminReason.isNotEmpty) {
        return VerificationDisplay(
          kind: VerificationDisplayKind.rejected,
          reason: adminReason,
        );
      }
      final String mapped = verificationReasonText(
        reasonCode: reasonCode,
        languageCode: languageCode,
      );
      if (mapped.isNotEmpty) {
        return VerificationDisplay(
          kind: VerificationDisplayKind.rejected,
          reason: decisionSource == 'admin' && adminReason.isNotEmpty
              ? adminReason
              : mapped,
        );
      }
      return VerificationDisplay(
        kind: VerificationDisplayKind.unknown,
        reason: _text(
          languageCode: languageCode,
          tr: 'Başvuru sonucu doğrulanamadı. Yeniden başvurabilirsin.',
          en: 'The application result could not be confirmed. You can apply again.',
          de: 'Das Antragsergebnis konnte nicht bestätigt werden. Du kannst den Antrag erneut stellen.',
        ),
      );
    default:
      return const VerificationDisplay(kind: VerificationDisplayKind.none);
  }
}
