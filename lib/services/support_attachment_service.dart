import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SupportAttachmentDraft {
  const SupportAttachmentDraft({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;

  int get sizeBytes => bytes.lengthInBytes;
}

class SupportAttachmentService {
  SupportAttachmentService._();

  static const int maxAttachmentCount = 3;
  static const int maxAttachmentBytes = 5 * 1024 * 1024;

  static Future<List<SupportAttachmentDraft>> pickScreenshots({
    required int remainingSlots,
  }) async {
    if (remainingSlots <= 0) {
      return const <SupportAttachmentDraft>[];
    }

    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: remainingSlots > 1,
      withData: true,
    );

    if (result == null) {
      return const <SupportAttachmentDraft>[];
    }

    final List<SupportAttachmentDraft> drafts = <SupportAttachmentDraft>[];

    for (final PlatformFile file in result.files.take(remainingSlots)) {
      final Uint8List? bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw StateError('Seçilen görsel okunamadı.');
      }

      if (bytes.lengthInBytes > maxAttachmentBytes) {
        throw StateError('Her ekran görüntüsü en fazla 5 MB olabilir.');
      }

      final String extension = (file.extension ?? '').trim().toLowerCase();
      final String contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => '',
      };

      if (contentType.isEmpty) {
        throw StateError('Desteklenmeyen görsel türü.');
      }

      drafts.add(
        SupportAttachmentDraft(
          name: file.name,
          bytes: bytes,
          contentType: contentType,
        ),
      );
    }

    return drafts;
  }

  static Future<List<String>> uploadDrafts(
    List<SupportAttachmentDraft> drafts,
  ) async {
    if (drafts.isEmpty) {
      return const <String>[];
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Ek dosya yüklemek için oturum açılmalıdır.');
    }

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final String draftId = firestore.collection('_local_ids').doc().id;
    final List<String> uploadedPaths = <String>[];

    try {
      for (final SupportAttachmentDraft draft in drafts) {
        final String objectId = firestore.collection('_local_ids').doc().id;
        final String extension = switch (draft.contentType) {
          'image/jpeg' => 'jpg',
          'image/png' => 'png',
          'image/webp' => 'webp',
          _ => throw StateError('Desteklenmeyen görsel türü.'),
        };

        final String path =
            'support_attachments/${user.uid}/$draftId/$objectId.$extension';

        final Reference reference = FirebaseStorage.instance.ref(path);

        await reference.putData(
          draft.bytes,
          SettableMetadata(
            contentType: draft.contentType,
            cacheControl: 'private,max-age=3600',
          ),
        );

        uploadedPaths.add(reference.fullPath);
      }

      return uploadedPaths;
    } catch (_) {
      await deletePaths(uploadedPaths);
      rethrow;
    }
  }

  static Future<void> deletePaths(Iterable<String> paths) async {
    for (final String path in paths) {
      final String normalized = path.trim();

      if (normalized.isEmpty) {
        continue;
      }

      try {
        await FirebaseStorage.instance.ref(normalized).delete();
      } catch (_) {}
    }
  }
}
