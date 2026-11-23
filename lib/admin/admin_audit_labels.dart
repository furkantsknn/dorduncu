import 'package:flutter/widgets.dart';

String adminAuditTitle(BuildContext context, String action) {
  final language = Localizations.localeOf(context).languageCode;
  final key = action.trim().toLowerCase();
  const labels = <String, List<String>>{
    'admin_reply_support': [
      'Destek talebi yanıtlandı',
      'Support request replied',
      'Supportanfrage beantwortet',
    ],
    'admin_note_support': [
      'Destek iç notu güncellendi',
      'Support note updated',
      'Supportnotiz aktualisiert',
    ],
    'admin_update_support_status': [
      'Destek durumu değiştirildi',
      'Support status changed',
      'Supportstatus geändert',
    ],
    'admin_update_event_status': [
      'Etkinlik durumu değiştirildi',
      'Event status changed',
      'Veranstaltungsstatus geändert',
    ],
    'admin_manage_user_badge': [
      'Kullanıcı rozeti yönetildi',
      'User badge managed',
      'Nutzerabzeichen verwaltet',
    ],
    'admin_update_membership': [
      'Üyelik güncellendi',
      'Membership updated',
      'Mitgliedschaft aktualisiert',
    ],
    'google_play_purchase_verified': [
      'Google Play satın alması doğrulandı',
      'Google Play purchase verified',
      'Google-Play-Kauf bestätigt',
    ],
    'account_deleted': ['Hesap silindi', 'Account deleted', 'Konto gelöscht'],
    'user_profile_viewed': [
      'Kullanıcı profili görüntülendi',
      'User profile viewed',
      'Nutzerprofil angezeigt',
    ],
  };
  final values = labels[key];
  if (values == null) {
    final readable = key.replaceAll('_', ' ').trim();
    return readable.isEmpty ? 'Bilinmeyen işlem' : readable;
  }
  return values[language == 'en'
      ? 1
      : language == 'de'
      ? 2
      : 0];
}
