class VerificationAdminLabels {
  const VerificationAdminLabels({
    required this.applicationStatus,
    required this.analysisStatus,
    required this.reason,
    required this.source,
    required this.identityRejection,
  });

  final String applicationStatus;
  final String analysisStatus;
  final String reason;
  final String source;
  final bool identityRejection;
}

bool verificationReasonIsTechnical(String reasonCode) {
  switch (reasonCode.trim()) {
    case 'identity_text_unreadable':
    case 'identity_terms_unmatched':
    case 'identity_type_mismatch':
    case 'identity_ocr_unavailable':
    case 'tckn_unreadable':
    case 'selfie_analysis_unavailable':
    case 'analysis_unavailable':
      return true;
    default:
      return false;
  }
}

String verificationAdminReasonLabel(String reasonCode) {
  switch (reasonCode.trim()) {
    case '':
      return 'Kayıtlı değil';
    case 'identity_terms_unmatched':
    case 'identity_type_mismatch':
      return 'Kimlik metni otomatik doğrulanamadı ($reasonCode)';
    case 'identity_text_unreadable':
    case 'identity_ocr_unavailable':
    case 'tckn_unreadable':
    case 'analysis_unavailable':
    case 'selfie_analysis_unavailable':
      return 'Otomatik analiz tamamlanamadı ($reasonCode)';
    case 'selfie_no_face':
    case 'selfie_multiple_faces':
    case 'selfie_unsuitable':
      return 'Uygun selfie ile yeniden başvuru ($reasonCode)';
    case 'identity_already_used':
      return 'Kimlik başka bir hesapta kayıtlı ($reasonCode)';
    case 'admin_decision':
      return 'Yönetici kararı ($reasonCode)';
    case 'revision_requested':
      return 'Düzeltme istendi ($reasonCode)';
    default:
      return 'Kayıtlı kod yorumlanamadı ($reasonCode)';
  }
}

VerificationAdminLabels presentVerificationAdmin({
  required String status,
  required String automaticCheckStatus,
  required String reasonCode,
  required String decisionSource,
}) {
  final String normalizedStatus = status.trim().toLowerCase();
  final String analysis = automaticCheckStatus.trim().toLowerCase();
  final String code = reasonCode.trim();
  final String source = decisionSource.trim().toLowerCase();
  final bool technical = verificationReasonIsTechnical(code);
  final bool selfie =
      code == 'selfie_no_face' ||
      code == 'selfie_multiple_faces' ||
      code == 'selfie_unsuitable';

  final String applicationStatus;
  var identityRejection = false;

  switch (normalizedStatus) {
    case 'approved':
      applicationStatus = 'Onaylandı';
    case 'revision':
      applicationStatus = 'Düzeltme istendi';
    case 'expired':
      applicationStatus = 'Süresi doldu';
    case 'pending':
    case 'needs_review':
      applicationStatus = 'İnceleme bekliyor';
    case '':
    case 'none':
    case 'notstarted':
      applicationStatus = 'Başvuru yok';
    case 'rejected':
      if (technical || code.isEmpty) {
        applicationStatus = 'Ret kaydı doğrulanamadı';
      } else if (selfie) {
        applicationStatus = 'Uygun selfie gerekli';
      } else if (code == 'identity_already_used') {
        applicationStatus = 'Kimlik başka hesapta kayıtlı';
        identityRejection = true;
      } else if (source == 'admin' || code == 'admin_decision') {
        applicationStatus = 'Yönetici reddetti';
        identityRejection = true;
      } else {
        applicationStatus = 'Reddedildi';
        identityRejection = true;
      }
    default:
      applicationStatus = 'Durum kayıtlı değil';
  }

  final String analysisStatus;
  switch (analysis) {
    case 'passed':
      analysisStatus = 'Temel kontroller geçti; kimlik-selfie yüz eşleşmesi yapılmadı';
    case 'needs_review':
      analysisStatus = 'Otomatik sonuç belirsiz';
    case 'failed':
      analysisStatus = technical
          ? 'Otomatik analiz tamamlanamadı'
          : 'Otomatik kontrol sonlandı';
    case 'processing':
      analysisStatus = 'Analiz sürüyor';
    case 'pending':
      analysisStatus = 'Analiz bekliyor';
    default:
      analysisStatus = analysis.isEmpty
          ? 'Kayıtlı değil'
          : 'Analiz durumu belirsiz';
  }

  final String sourceLabel = switch (source) {
    'automatic' => 'Otomatik analiz',
    'admin' => 'Yönetici',
    _ => 'Kayıtlı değil',
  };

  return VerificationAdminLabels(
    applicationStatus: applicationStatus,
    analysisStatus: analysisStatus,
    reason: verificationAdminReasonLabel(code),
    source: sourceLabel,
    identityRejection: identityRejection,
  );
}
