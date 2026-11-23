import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AdminUserNumberState { loading, available, missing, error }

AdminUserNumberState resolveAdminUserNumberState({
  required bool hasData,
  required bool hasError,
  required bool documentExists,
  required String number,
}) {
  if (hasError) return AdminUserNumberState.error;
  if (!hasData) return AdminUserNumberState.loading;
  if (!documentExists || number.trim().isEmpty) {
    return AdminUserNumberState.missing;
  }
  return AdminUserNumberState.available;
}

Future<String?> findUidByManagementNumber(String input) async {
  final number = input.trim().toUpperCase();
  if (!RegExp(r'^U-\d{6,}$').hasMatch(number)) return null;
  final result = await FirebaseFirestore.instance
      .collection('admin_user_metadata')
      .where('managementNumber', isEqualTo: number)
      .limit(1)
      .get(const GetOptions(source: Source.server));
  return result.docs.isEmpty ? null : result.docs.first.id;
}

/// Reads the server-only management metadata for one visible admin detail.
class AdminUserNumber extends StatelessWidget {
  const AdminUserNumber({
    required this.uid,
    this.showTechnicalUid = false,
    super.key,
  });

  final String uid;
  final bool showTechnicalUid;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_user_metadata')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final String number =
            snapshot.data?.data()?['managementNumber']?.toString() ?? '';
        final AdminUserNumberState state = resolveAdminUserNumberState(
          hasData: snapshot.hasData,
          hasError: snapshot.hasError,
          documentExists: snapshot.data?.exists == true,
          number: number,
        );
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ActionChip(
              avatar: state == AdminUserNumberState.loading
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      state == AdminUserNumberState.error
                          ? Icons.error_outline
                          : Icons.tag,
                      size: 17,
                    ),
              label: Text(switch (state) {
                AdminUserNumberState.loading => 'Numara yükleniyor',
                AdminUserNumberState.available => number,
                AdminUserNumberState.missing => 'Numara henüz atanmadı',
                AdminUserNumberState.error => 'Yönetim numarası alınamadı',
              }),
              onPressed: state != AdminUserNumberState.available
                  ? null
                  : () => Clipboard.setData(ClipboardData(text: number)),
            ),
            if (showTechnicalUid)
              ActionChip(
                avatar: const Icon(Icons.key_outlined, size: 17),
                label: const Text('Teknik UID’yi kopyala'),
                onPressed: () => Clipboard.setData(ClipboardData(text: uid)),
              ),
          ],
        );
      },
    );
  }
}

class AdminUserIdentity extends StatelessWidget {
  const AdminUserIdentity({
    required this.uid,
    this.compact = false,
    this.showTechnicalUid = false,
    super.key,
  });

  final String uid;
  final bool compact;
  final bool showTechnicalUid;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const Text('Kullanıcı bilgisi yok');
    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, userSnapshot) {
        final data = userSnapshot.data?.data() ?? const <String, dynamic>{};
        final name =
            <String>[
              data['profilAdi']?.toString().trim() ?? '',
              '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim(),
            ].firstWhere(
              (value) => value.isNotEmpty,
              orElse: () => 'Silinmiş veya eski kullanıcı',
            );
        final rawPhoto = (data['profilFotografi'] ?? data['avatarUrl'] ?? '')
            .toString()
            .trim();
        final version =
            (data['photoGeneration'] ??
                    data['profilePhotoVersion'] ??
                    data['updatedAt']?.hashCode ??
                    '')
                .toString();
        final photo = rawPhoto.isEmpty || version.isEmpty
            ? rawPhoto
            : Uri.parse(rawPhoto)
                  .replace(
                    queryParameters: <String, String>{
                      ...Uri.parse(rawPhoto).queryParameters,
                      'v': version,
                    },
                  )
                  .toString();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: compact ? 18 : 23,
              foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
              child: photo.isEmpty ? const Icon(Icons.person_outline) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  AdminUserNumber(uid: uid, showTechnicalUid: showTechnicalUid),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
