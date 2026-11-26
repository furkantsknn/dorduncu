import 'package:dorduncu/utils/verification_admin_labels.dart';
import 'package:dorduncu/utils/verification_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing status is not shown as rejected', () {
    final VerificationDisplay display = presentVerificationStatus(
      status: '',
      reasonCode: '',
      decisionReason: '',
      decisionSource: '',
      languageCode: 'tr',
    );

    expect(display.kind, VerificationDisplayKind.none);
    expect(display.showRejected, isFalse);
  });

  test('rejected without a reason code stays unconfirmed', () {
    final VerificationDisplay display = presentVerificationStatus(
      status: 'rejected',
      reasonCode: '',
      decisionReason: '',
      decisionSource: '',
      languageCode: 'tr',
    );

    expect(display.kind, VerificationDisplayKind.unknown);
    expect(display.showRejected, isFalse);
    expect(display.allowReapply, isTrue);
    expect(display.reason, isNot(contains('Reddedildi')));
  });

  test('automatic rejection shows a mapped reason', () {
    final VerificationDisplay display = presentVerificationStatus(
      status: 'rejected',
      reasonCode: 'selfie_no_face',
      decisionReason: '',
      decisionSource: 'automatic',
      languageCode: 'en',
    );

    expect(display.showRejected, isTrue);
    expect(display.reason, 'Apply again with a suitable selfie.');
    expect(display.reason.toLowerCase(), isNot(contains('fake')));
  });

  test('multiple faces use the same selfie reapply text', () {
    final VerificationDisplay display = presentVerificationStatus(
      status: 'rejected',
      reasonCode: 'selfie_multiple_faces',
      decisionReason: '',
      decisionSource: 'automatic',
      languageCode: 'tr',
    );

    expect(display.reason, 'Uygun selfie ile yeniden başvur.');
  });

  test('unmatched identity text is not an identity rejection for admins', () {
    final VerificationAdminLabels labels = presentVerificationAdmin(
      status: 'pending',
      automaticCheckStatus: 'needs_review',
      reasonCode: 'identity_terms_unmatched',
      decisionSource: 'automatic',
    );

    expect(labels.applicationStatus, 'İnceleme bekliyor');
    expect(labels.analysisStatus, 'Otomatik sonuç belirsiz');
    expect(labels.identityRejection, isFalse);
    expect(labels.source, 'Otomatik analiz');
  });

  test(
    'a rejected record without a reason is not labeled as identity rejection',
    () {
      final VerificationAdminLabels labels = presentVerificationAdmin(
        status: 'rejected',
        automaticCheckStatus: 'failed',
        reasonCode: '',
        decisionSource: '',
      );

      expect(labels.applicationStatus, 'Ret kaydı doğrulanamadı');
      expect(labels.reason, 'Kayıtlı değil');
      expect(labels.source, 'Kayıtlı değil');
      expect(labels.identityRejection, isFalse);
    },
  );

  test('pending stays pending even with an internal reason code', () {
    final VerificationDisplay display = presentVerificationStatus(
      status: 'pending',
      reasonCode: 'analysis_unavailable',
      decisionReason: '',
      decisionSource: 'automatic',
      languageCode: 'de',
    );

    expect(display.kind, VerificationDisplayKind.pending);
    expect(display.reason, isEmpty);
  });

  test('admin decision uses the stored explanation', () {
    final VerificationDisplay display = presentVerificationStatus(
      status: 'rejected',
      reasonCode: 'admin_decision',
      decisionReason: 'Belge okunmuyor',
      decisionSource: 'admin',
      languageCode: 'tr',
    );

    expect(display.showRejected, isTrue);
    expect(display.reason, 'Belge okunmuyor');
  });

  test('passed basic checks never imply selfie identity matching', () {
    final VerificationAdminLabels labels = presentVerificationAdmin(
      status: 'pending',
      automaticCheckStatus: 'passed',
      reasonCode: '',
      decisionSource: 'automatic',
    );

    expect(labels.applicationStatus, 'İnceleme bekliyor');
    expect(labels.analysisStatus, contains('yüz eşleşmesi yapılmadı'));
    expect(labels.identityRejection, isFalse);
  });

  test('biometric and queue reason codes map to clear admin labels', () {
    expect(
      verificationAdminReasonLabel('face_mismatch_requires_review'),
      contains('insan incelemesi'),
    );
    expect(
      verificationAdminReasonLabel('selfie_liveness_retry'),
      contains('yeniden çekim'),
    );
    expect(
      verificationAdminReasonLabel('analysis_retries_exhausted'),
      contains('manuel inceleme'),
    );
    expect(verificationReasonIsTechnical('analysis_retries_exhausted'), isTrue);
  });
}
