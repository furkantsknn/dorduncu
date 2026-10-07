import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../services/language_controller.dart';
import '../utils/verification_reason.dart';

String _verificationText(
  String languageCode, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (languageCode) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ImagePicker imagePicker = ImagePicker();

  PlatformFile? identityFront;

  XFile? selfiePhoto;

  bool loading = false;

  Map<String, dynamic>? verificationData;
  Map<String, dynamic>? userData;

  bool loadingVerification = true;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  verificationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSubscription;

  _VerificationText get text {
    return _VerificationText(LanguageController.language.value);
  }

  @override
  void initState() {
    super.initState();
    listenVerification();
  }

  void listenVerification() {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        loadingVerification = false;
      });
      return;
    }

    verificationSubscription = FirebaseFirestore.instance
        .collection('verification_requests')
        .doc(user.uid)
        .snapshots()
        .listen(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) {
            if (!mounted) return;

            setState(() {
              verificationData = snapshot.data();
              loadingVerification = false;
            });
          },
          onError: (_) {
            if (!mounted) return;

            setState(() {
              loadingVerification = false;
            });

            showMessage('Başvuru bilgileri yüklenemedi.');
          },
        );

    userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          if (!mounted) return;

          setState(() {
            userData = snapshot.data();
          });
        });
  }

  @override
  void dispose() {
    verificationSubscription?.cancel();
    userSubscription?.cancel();
    super.dispose();
  }

  bool get documentsComplete {
    return identityFront != null && selfiePhoto != null;
  }

  Future<PlatformFile?> selectDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final PlatformFile file = result.files.first;

      if (file.path == null) {
        showMessage(text.selectedFileCouldNotBeAccessed);
        return null;
      }

      const int maximumSize = 10 * 1024 * 1024;

      if (file.size > maximumSize) {
        showMessage(text.maximumFileSize);
        return null;
      }

      return file;
    } catch (_) {
      showMessage(text.documentSelectionFailed);
      return null;
    }
  }

  Future<PlatformFile?> selectIdentityImage() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xff171A20),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (BuildContext sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.orange,
                    ),
                    title: const Text(
                      'Kameradan çek',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext, ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.orange,
                    ),
                    title: const Text(
                      'Galeriden seç',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext, ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (source == null) {
        return null;
      }

      final XFile? image = await imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
      );

      if (image == null) {
        return null;
      }

      final File file = File(image.path);
      final int size = await file.length();

      const int maximumSize = 10 * 1024 * 1024;

      if (size > maximumSize) {
        showMessage(text.maximumFileSize);
        return null;
      }

      return PlatformFile(name: image.name, path: image.path, size: size);
    } catch (_) {
      showMessage(text.documentSelectionFailed);
      return null;
    }
  }

  Future<void> selectIdentityFront() async {
    final PlatformFile? file = await selectIdentityImage();

    if (file == null || !mounted) return;

    setState(() {
      identityFront = file;
    });
  }

  Future<void> selectSelfie() async {
    try {
      final XFile? photo = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (photo == null || !mounted) return;

      setState(() {
        selfiePhoto = photo;
      });
    } catch (_) {
      showMessage(text.selfieCouldNotBeTaken);
    }
  }

  String fileExtension(String fileName) {
    final List<String> parts = fileName.split('.');

    if (parts.length < 2) {
      return 'file';
    }

    return parts.last.toLowerCase();
  }

  Future<String> uploadFile({required File file, required String path}) async {
    final Reference reference = FirebaseStorage.instance.ref().child(path);

    final TaskSnapshot snapshot = await reference.putFile(file);

    return snapshot.ref.fullPath;
  }

  Future<void> submitVerification() async {
    if (!documentsComplete) {
      showMessage(text.requiredVerificationDocuments);
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(text.sessionNotFound);
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final String basePath = 'verification_documents/${user.uid}';

      final String identityFrontPath = await uploadFile(
        file: File(identityFront!.path!),
        path:
            '$basePath/identity_front_$timestamp.${fileExtension(identityFront!.name)}',
      );

      final String selfiePath = await uploadFile(
        file: File(selfiePhoto!.path),
        path: '$basePath/selfie_$timestamp.jpg',
      );

      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('submitVerification');

      await callable.call(<String, dynamic>{
        'identityFrontPath': identityFrontPath,
        'selfiePath': selfiePath,
      });

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.verificationApplicationSent)));
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(error.message ?? text.documentsUploadFailed);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(text.documentsUploadFailedWithError(error.toString()));
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ignore: unused_element
  Future<void> _requestDocumentDeletion() async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('requestVerificationDocumentDeletion');

      await callable.call(<String, dynamic>{});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Doğrulama belgelerin silindi. '
            'Doğrulama sonucu ve güvenlik kayıtları saklanabilir.',
          ),
        ),
      );

      setState(() {});
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Belge silme işlemi tamamlanamadı.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (context, language, _) {
        final _VerificationText text = _VerificationText(language);

        final String requestStatus =
            verificationData?['status']?.toString() ?? '';

        final bool userApproved =
            userData?['oyuncuRozeti'] == true ||
            userData?['verified'] == true ||
            userData?['verificationStatus'] == 'approved';

        final String status = userApproved ? 'approved' : requestStatus;

        final bool isApproved = status == 'approved';
        final bool isPending = status == 'pending';
        final bool isRevision = status == 'revision';
        final bool isExpired = status == 'expired';

        final String decisionReason =
            verificationData?['decisionReason']?.toString().trim().isNotEmpty ==
                true
            ? verificationData!['decisionReason'].toString()
            : verificationData?['adminNote']?.toString() ?? '';

        final Timestamp? reviewedAt =
            verificationData?['reviewedAt'] as Timestamp?;

        final String languageCode = switch (language) {
          AppLanguage.english => 'en',
          AppLanguage.german => 'de',
          AppLanguage.turkish => 'tr',
        };
        final VerificationDisplay verificationDisplay =
            presentVerificationStatus(
              status: status,
              reasonCode:
                  verificationData?['reasonCode']?.toString() ??
                  userData?['verificationReasonCode']?.toString() ??
                  '',
              decisionReason: decisionReason,
              decisionSource:
                  verificationData?['decisionSource']?.toString() ??
                  userData?['verificationDecisionSource']?.toString() ??
                  '',
              languageCode: languageCode,
            );
        final Timestamp? decidedAt =
            verificationData?['decidedAt'] as Timestamp? ?? reviewedAt;
        final DateTime? decisionDate = decidedAt?.toDate();

        final bool canSendDocuments =
            !userApproved &&
            !isPending &&
            !isApproved &&
            (verificationData == null || verificationDisplay.allowReapply);

        if (loadingVerification) {
          return const Scaffold(
            backgroundColor: Color(0xff0F1115),
            body: Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xff0F1115),
          appBar: AppBar(
            backgroundColor: const Color(0xff0F1115),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              text.playerVerification,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.orange,
                  size: 75,
                ),
                const SizedBox(height: 18),
                Text(
                  text.verifyYourAccount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  text.verificationDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff171A20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isApproved
                          ? Colors.blue
                          : const Color(0xffFF9800).withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            isApproved
                                ? Icons.verified_rounded
                                : Icons.verified_outlined,
                            color: isApproved ? Colors.blue : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isApproved
                                  ? _verificationMeaning(
                                      language,
                                      tr: 'Hesabın doğrulanmış',
                                      en: 'Your account is verified',
                                      de: 'Dein Konto ist verifiziert',
                                    )
                                  : isPending
                                  ? _verificationMeaning(
                                      language,
                                      tr: 'Doğrulama inceleniyor',
                                      en: 'Verification is in review',
                                      de: 'Verifizierung wird geprüft',
                                    )
                                  : _verificationMeaning(
                                      language,
                                      tr: 'Hesap henüz doğrulanmadı',
                                      en: 'Account is not verified yet',
                                      de: 'Konto ist noch nicht verifiziert',
                                    ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _verificationMeaning(
                          language,
                          tr: 'Doğrulanmış hesap, kimlik kontrolünün Dört. tarafından onaylandığını gösterir. Mavi tik yalnızca sunucu kararıyla görünür.',
                          en: 'A verified account means identity review was approved by Dört. The blue check is granted only by the server.',
                          de: 'Ein verifiziertes Konto bedeutet, dass die Identitätsprüfung von Dört. genehmigt wurde. Das blaue Häkchen vergibt nur der Server.',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff171A20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.privacy_tip_outlined,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text.verificationPrivacyNotice,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xff171A20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orangeAccent),
                  ),
                  child: Text(
                    text.verificationBadgeDisclaimer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                if (verificationData != null || userApproved)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xff171A20),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: switch (verificationDisplay.kind) {
                          VerificationDisplayKind.approved => Colors.green,
                          VerificationDisplayKind.rejected => Colors.red,
                          VerificationDisplayKind.revision ||
                          VerificationDisplayKind.unknown => Colors.orange,
                          VerificationDisplayKind.expired => Colors.grey,
                          _ => Colors.blueGrey,
                        },
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Başvuru Durumu',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          verificationStatusTitle(
                            kind: verificationDisplay.kind,
                            languageCode: languageCode,
                          ),
                          style: TextStyle(
                            color:
                                verificationDisplay.kind ==
                                    VerificationDisplayKind.approved
                                ? Colors.green
                                : verificationDisplay.kind ==
                                      VerificationDisplayKind.rejected
                                ? Colors.red
                                : verificationDisplay.kind ==
                                      VerificationDisplayKind.unknown
                                ? Colors.orange
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (verificationDisplay.reason.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 12),
                          Text(
                            verificationDisplay.showRejected
                                ? _verificationText(
                                    languageCode,
                                    tr: 'Ret sebebi',
                                    en: 'Rejection reason',
                                    de: 'Ablehnungsgrund',
                                  )
                                : _verificationText(
                                    languageCode,
                                    tr: 'Durum',
                                    en: 'Status',
                                    de: 'Status',
                                  ),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            verificationDisplay.reason,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                          if (decisionDate != null &&
                              verificationDisplay.showRejected) ...[
                            const SizedBox(height: 12),
                            Text(
                              _verificationText(
                                languageCode,
                                tr:
                                    'Karar tarihi: '
                                    '${decisionDate.day.toString().padLeft(2, '0')}.'
                                    '${decisionDate.month.toString().padLeft(2, '0')}.'
                                    '${decisionDate.year}',
                                en:
                                    'Decision date: '
                                    '${decisionDate.day.toString().padLeft(2, '0')}.'
                                    '${decisionDate.month.toString().padLeft(2, '0')}.'
                                    '${decisionDate.year}',
                                de:
                                    'Entscheidungsdatum: '
                                    '${decisionDate.day.toString().padLeft(2, '0')}.'
                                    '${decisionDate.month.toString().padLeft(2, '0')}.'
                                    '${decisionDate.year}',
                              ),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                if (isPending)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'Başvurun inceleniyor. İnceleme tamamlanana kadar yeni belge gönderemezsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),

                if (isApproved)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'Doğrulama başvurun onaylandı. Oyuncu rozetin hesabına eklendi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),

                if (isRevision)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Yönetici tarafından revizyon istendi. Belgelerini yeniden seçerek başvurunu tekrar gönderebilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                if (isExpired)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      text.verificationExpiredMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                if (verificationDisplay.showRejected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _verificationText(
                        languageCode,
                        tr: 'Belgelerini yeniden hazırlayarak tekrar başvurabilirsin.',
                        en: 'You can prepare your documents and apply again.',
                        de: 'Du kannst deine Dokumente erneut vorbereiten und den Antrag noch einmal stellen.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                if (canSendDocuments)
                  Column(
                    children: [
                      _documentCard(
                        title: text.identityFront,
                        subtitle: identityFront?.name,
                        emptySubtitle: text.tapToSelect,
                        icon: Icons.credit_card,
                        selected: identityFront != null,
                        onTap: selectIdentityFront,
                      ),
                      const SizedBox(height: 13),
                      const SizedBox(height: 13),
                      _documentCard(
                        title: text.takeSelfie,
                        subtitle: selfiePhoto == null ? null : text.selfieReady,
                        emptySubtitle: text.tapToTakeSelfie,
                        icon: Icons.camera_alt_outlined,
                        selected: selfiePhoto != null,
                        onTap: selectSelfie,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        text.supportedDocumentTypes,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: loading || !documentsComplete
                              ? null
                              : submitVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            disabledBackgroundColor: Colors.white12,
                            foregroundColor: Colors.black,
                            disabledForegroundColor: Colors.white38,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  isRevision
                                      ? 'Revizyonu Gönder'
                                      : verificationDisplay.showRejected ||
                                            verificationDisplay.kind ==
                                                VerificationDisplayKind.unknown
                                      ? _verificationText(
                                          languageCode,
                                          tr: 'Yeniden Başvur',
                                          en: 'Apply again',
                                          de: 'Erneut beantragen',
                                        )
                                      : text.sendApplication,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _documentCard({
    required String title,
    required String? subtitle,
    required String emptySubtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xff171A20),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? Colors.orange : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? Icons.check_circle : icon,
                  color: selected ? Colors.orange : Colors.white70,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle ?? emptySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.orange : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationText {
  const _VerificationText(this.language);

  final AppLanguage language;

  String value(String turkish, String english, String german) {
    switch (language) {
      case AppLanguage.turkish:
        return turkish;
      case AppLanguage.english:
        return english;
      case AppLanguage.german:
        return german;
    }
  }

  String get playerVerification =>
      value('Oyuncu Doğrulama', 'Player Verification', 'Spielerverifizierung');

  String get verifyYourAccount =>
      value('Hesabını Doğrula', 'Verify Your Account', 'Bestätige dein Konto');

  String get verificationDescription => value(
    'Gönderdiğin belgeler, oyuncu doğrulama adımlarını tamamlayıp tamamlamadığını değerlendirmek için incelenir.',
    'The documents you submit are reviewed to determine whether you completed the player verification steps.',
    'Die von dir eingereichten Dokumente werden geprüft, um festzustellen, ob du die Schritte der Spielerverifizierung abgeschlossen hast.',
  );

  String get verificationPrivacyNotice => value(
    'Yalnızca kimlik ön yüzü ve selfie oyuncu doğrulama amacıyla işlenir. Kimlik arka yüzü veya adli sicil belgesi istenmez. Bu işlem için gerekli olmayan ek kişisel verileri paylaşmamaya dikkat et.',
    'Only the front of your ID and a selfie are processed for player verification. The back of the ID and a criminal record document are not requested. Avoid sharing unnecessary personal data.',
    'Für die Spielerverifizierung werden nur die Vorderseite des Ausweises und ein Selfie verarbeitet. Ausweisrückseite und Führungszeugnis werden nicht angefordert. Teile keine unnötigen personenbezogenen Daten.',
  );

  String get verificationBadgeDisclaimer => value(
    'Doğrulama rozeti yalnızca belirtilen doğrulama adımlarının tamamlandığını gösterir. Bir kişinin güvenilir, güvenli veya risksiz olduğunu garanti etmez.',
    'The verification badge only indicates that the stated verification steps were completed. It does not guarantee that a person is trustworthy, safe or risk-free.',
    'Das Verifizierungsabzeichen zeigt nur, dass die angegebenen Verifizierungsschritte abgeschlossen wurden. Es garantiert nicht, dass eine Person vertrauenswürdig, sicher oder risikofrei ist.',
  );

  String get verificationExpiredMessage => value(
    'Önceki doğrulamanın süresi dolmuş. Güncel belgelerle yeniden başvuru yapabilirsin.',
    'Your previous verification has expired. You can apply again with current documents.',
    'Deine vorherige Verifizierung ist abgelaufen. Du kannst dich mit aktuellen Dokumenten erneut bewerben.',
  );

  String get identityFront =>
      value('Kimlik Ön Yüzü', 'Front of ID', 'Vorderseite des Ausweises');

  String get identityBack =>
      value('Kimlik Arka Yüzü', 'Back of ID', 'Rückseite des Ausweises');

  String get criminalRecordDocument => value(
    'Adli Sicil Belgesi',
    'Criminal Record Document',
    'Führungszeugnis',
  );

  String get takeSelfie =>
      value('Selfie Çek', 'Take a Selfie', 'Selfie aufnehmen');

  String get selfieReady =>
      value('Selfie hazır', 'Selfie is ready', 'Selfie ist bereit');
  String get tapToSelect =>
      value('Seçmek için dokun', 'Tap to select', 'Zum Auswählen tippen');

  String get tapToTakeSelfie => value(
    'Selfie çekmek için dokun',
    'Tap to take a selfie',
    'Tippen, um ein Selfie aufzunehmen',
  );

  String get supportedDocumentTypes => value(
    'PDF, JPG veya PNG dosyaları kabul edilir. En fazla 10 MB yükleyebilirsin.',
    'PDF, JPG or PNG files are accepted. You can upload a maximum of 10 MB.',
    'PDF-, JPG- oder PNG-Dateien werden akzeptiert. Du kannst maximal 10 MB hochladen.',
  );

  String get sendApplication =>
      value('Başvuruyu Gönder', 'Send Application', 'Antrag senden');

  String get selectedFileCouldNotBeAccessed => value(
    'Seçilen dosyaya erişilemedi.',
    'The selected file could not be accessed.',
    'Auf die ausgewählte Datei konnte nicht zugegriffen werden.',
  );

  String get maximumFileSize => value(
    'Dosya boyutu en fazla 10 MB olabilir.',
    'The file size can be a maximum of 10 MB.',
    'Die Dateigröße darf maximal 10 MB betragen.',
  );

  String get documentSelectionFailed => value(
    'Belge seçilirken bir hata oluştu.',
    'An error occurred while selecting the document.',
    'Beim Auswählen des Dokuments ist ein Fehler aufgetreten.',
  );

  String get selfieCouldNotBeTaken => value(
    'Selfie çekilemedi.',
    'The selfie could not be taken.',
    'Das Selfie konnte nicht aufgenommen werden.',
  );

  String get requiredVerificationDocuments => value(
    'Tüm belgeleri ve selfie fotoğrafını eklemelisin.',
    'You must add all documents and a selfie photo.',
    'Du musst alle Dokumente und ein Selfie hinzufügen.',
  );

  String get sessionNotFound => value(
    'Kullanıcı oturumu bulunamadı.',
    'User session could not be found.',
    'Die Benutzersitzung wurde nicht gefunden.',
  );

  String get verificationApplicationSent => value(
    'Doğrulama başvurun gönderildi.',
    'Your verification application has been sent.',
    'Dein Verifizierungsantrag wurde gesendet.',
  );

  String get documentsUploadFailed => value(
    'Belgeler yüklenirken bir hata oluştu.',
    'An error occurred while uploading the documents.',
    'Beim Hochladen der Dokumente ist ein Fehler aufgetreten.',
  );

  String documentsUploadFailedWithError(String error) {
    return value(
      'Belgeler yüklenirken bir hata oluştu: $error',
      'An error occurred while uploading the documents: $error',
      'Beim Hochladen der Dokumente ist ein Fehler aufgetreten: $error',
    );
  }
}

String _verificationMeaning(
  AppLanguage language, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (language) {
    case AppLanguage.english:
      return en;
    case AppLanguage.german:
      return de;
    case AppLanguage.turkish:
      return tr;
  }
}
