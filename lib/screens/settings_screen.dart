import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/language_controller.dart';
import '../services/notification_push_service.dart';
import '../services/session_service.dart';
import '../services/theme_controller.dart';
import 'change_phone_screen.dart';
import 'legal_document_screen.dart';
import 'login_screen.dart';
import 'support_center_screen.dart';
import '../widgets/app_admin_menu_entry.dart';
import 'blocked_users_screen.dart';

String _settingsText(
  BuildContext context, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint("SETTINGS SCREEN OPENED");
    _load();
  }

  bool messages = true;
  bool events = true;
  bool applications = true;
  bool campaigns = false;
  bool quietHoursEnabled = false;
  bool loading = true;
  bool deletionBusy = false;

  Future<void> _load() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? uid = user?.uid;

    if (uid == null) {
      if (mounted) {
        setState(() => loading = false);
      }
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get(const GetOptions(source: Source.server));

      final Map<String, dynamic> userData =
          document.data() ?? <String, dynamic>{};

      final Map<String, dynamic> preferences = Map<String, dynamic>.from(
        userData['bildirimAyarlari'] ?? const <String, dynamic>{},
      );

      if (!mounted) {
        return;
      }

      setState(() {
        messages = preferences['mesajlar'] ?? true;
        events = preferences['etkinlikler'] ?? true;
        applications = preferences['basvurular'] ?? true;
        campaigns = preferences['kampanyalar'] ?? false;
        quietHoursEnabled = preferences['sessizSaatlerAktif'] ?? false;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _save() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      <String, dynamic>{
        'bildirimAyarlari': <String, dynamic>{
          'mesajlar': messages,
          'etkinlikler': events,
          'basvurular': applications,
          'kampanyalar': campaigns,
          'sessizSaatlerAktif': quietHoursEnabled,
          'sessizBaslangic': '22:00',
          'sessizBitis': '08:00',
          'timezone': 'Europe/Istanbul',
        },
      },
      SetOptions(merge: true),
    );

    if (messages || events || applications || campaigns) {
      await NotificationPushService.ensurePermissionAndRegister();
    }
  }

  Future<void> _requestAccountDeletion() async {
    if (deletionBusy) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        _settingsText(
          context,
          tr: 'Hesap silme talebi oluşturmak için giriş yapmalısın.',
          en: 'You must sign in to request account deletion.',
          de: 'Du musst angemeldet sein, um die Löschung deines Kontos zu beantragen.',
        ),
      );
      return;
    }

    final bool? firstConfirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _settingsText(
              dialogContext,
              tr: 'Hesap silme talebi',
              en: 'Account deletion request',
              de: 'Antrag auf Kontolöschung',
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              _settingsText(
                dialogContext,
                tr: 'Hesabın bu onayla hemen silinmez. Talep kaydedilir, oturumun kapanır ve işlem bitene kadar hesabı kullanamazsın.\n\nİşlem tamamlandığında hesap girişin, profilin, herkese açık profilin, profil fotoğrafların ve doğrulama belgelerin silinir.\n\nBaşka kullanıcıların etkinlik ve mesaj kayıtları ile güvenlik, uyuşmazlık veya yasal ya da finansal yükümlülük için gerekli sınırlı kayıtlar tutulabilir. Gönüllü hesap silme talebi tek başına telefon numaran için güvenlik yasağı oluşturmaz.\n\nUygulamaya giremiyorsan kayıtlı telefon numaranla destek@dortapp.com adresine “Dört. Hesap Silme Talebi” konulu e-posta gönderebilirsin. E-posta tek başına silmeyi tamamlamaz.',
                en: 'Your account is not deleted by this confirmation alone. The request is recorded, you are signed out, and you cannot use the account until processing finishes.\n\nWhen processing completes, your login, profile, public profile, profile photos and verification documents are deleted.\n\nOther users’ event and message records, and limited records needed for security, a dispute, or a legal or financial duty, may be kept. A voluntary account-deletion request does not itself create a security ban for your phone number.\n\nIf you cannot open the app, email destek@dortapp.com with your registered phone number and the subject “Dört. Account Deletion Request”. The email alone does not finish deletion.',
                de: 'Dein Konto wird durch diese Bestätigung nicht sofort gelöscht. Der Antrag wird gespeichert, du wirst abgemeldet und kannst das Konto bis zum Abschluss nicht nutzen.\n\nNach Abschluss werden Anmeldung, Profil, öffentliches Profil, Profilfotos und Verifizierungsdokumente gelöscht.\n\nVeranstaltungs- und Nachrichtendaten anderer Nutzer sowie begrenzte Aufzeichnungen für Sicherheit, einen Streitfall oder eine rechtliche oder finanzielle Pflicht können bleiben. Ein freiwilliger Kontolöschantrag führt allein nicht zu einer Sicherheitssperre deiner Telefonnummer.\n\nWenn du die App nicht öffnen kannst, schreibe mit deiner registrierten Telefonnummer an destek@dortapp.com. Betreff: „Dört. Kontolöschung“. Die E-Mail allein schließt die Löschung nicht ab.',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                _settingsText(
                  dialogContext,
                  tr: 'Vazgeç',
                  en: 'Cancel',
                  de: 'Abbrechen',
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                _settingsText(
                  dialogContext,
                  tr: 'Devam et',
                  en: 'Continue',
                  de: 'Weiter',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (firstConfirmation != true || !mounted) {
      return;
    }

    final bool? finalConfirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            _settingsText(
              dialogContext,
              tr: 'Son onay',
              en: 'Final confirmation',
              de: 'Letzte Bestätigung',
            ),
          ),
          content: Text(
            _settingsText(
              dialogContext,
              tr: 'Silme talebi oluşturulduktan sonra oturumun kapatılacak ve işlem tamamlanana kadar uygulamaya erişemeyeceksin.',
              en: 'After the deletion request is created, you will be signed out and unable to access the app until the process is completed.',
              de: 'Nach dem Löschantrag wirst du abgemeldet und kannst bis zum Abschluss nicht auf die App zugreifen.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                _settingsText(dialogContext, tr: 'Hayır', en: 'No', de: 'Nein'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                _settingsText(
                  dialogContext,
                  tr: 'Talebi oluştur',
                  en: 'Create request',
                  de: 'Antrag erstellen',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (finalConfirmation != true || !mounted) {
      return;
    }

    setState(() {
      deletionBusy = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('requestAccountDeletion');

      await callable.call();

      await SessionService.clearSession();
      await NotificationPushService.unregisterCurrentToken();
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ??
            _settingsText(
              context,
              tr: 'Hesap silme talebi oluşturulamadı.',
              en: 'The account deletion request could not be created.',
              de: 'Der Antrag auf Kontolöschung konnte nicht erstellt werden.',
            ),
      );
    } catch (_) {
      _showMessage(
        _settingsText(
          context,
          tr: 'Hesap silme talebi oluşturulamadı.',
          en: 'The account deletion request could not be created.',
          de: 'Der Antrag auf Kontolöschung konnte nicht erstellt werden.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          deletionBusy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _document(String documentCode) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(documentCode: documentCode),
      ),
    );
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    await LanguageController.setLanguage(language);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: <Widget>[
          AppAdminMenuEntry(
            builder: (BuildContext context, VoidCallback openAdminPanel) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: Text(AppAdminMenuEntry.label(context)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: openAdminPanel,
                  ),
                ),
              );
            },
          ),
          _title(
            _settingsText(
              context,
              tr: 'Bildirimler',
              en: 'Notifications',
              de: 'Benachrichtigungen',
            ),
          ),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: messages,
                  onChanged: (bool value) {
                    setState(() => messages = value);
                    _save();
                  },
                  secondary: const Icon(Icons.chat_bubble_outline),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Mesaj bildirimleri',
                      en: 'Message notifications',
                      de: 'Nachrichtenbenachrichtigungen',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: events,
                  onChanged: (bool value) {
                    setState(() => events = value);
                    _save();
                  },
                  secondary: const Icon(Icons.event_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Etkinlik bildirimleri',
                      en: 'Event notifications',
                      de: 'Veranstaltungsbenachrichtigungen',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: applications,
                  onChanged: (bool value) {
                    setState(() => applications = value);
                    _save();
                  },
                  secondary: const Icon(Icons.how_to_reg_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Başvuru bildirimleri',
                      en: 'Application notifications',
                      de: 'Bewerbungsbenachrichtigungen',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: campaigns,
                  onChanged: (bool value) {
                    setState(() => campaigns = value);
                    _save();
                  },
                  secondary: const Icon(Icons.campaign_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Kampanya bildirimleri',
                      en: 'Campaign notifications',
                      de: 'Kampagnenbenachrichtigungen',
                    ),
                  ),
                ),
                SwitchListTile(
                  value: quietHoursEnabled,
                  onChanged: (bool value) {
                    setState(() => quietHoursEnabled = value);
                    _save();
                  },
                  secondary: const Icon(Icons.bedtime_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Sessiz saatler',
                      en: 'Quiet hours',
                      de: 'Ruhezeiten',
                    ),
                  ),
                  subtitle: Text(
                    _settingsText(
                      context,
                      tr: '22:00 - 08:00 arasında push bildirimi bekletilir.',
                      en: 'Push notifications wait between 22:00 and 08:00.',
                      de: 'Push-Benachrichtigungen warten von 22:00 bis 08:00.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _title(l10n.language),
          ValueListenableBuilder<AppLanguage>(
            valueListenable: LanguageController.language,
            builder:
                (
                  BuildContext context,
                  AppLanguage selectedLanguage,
                  Widget? child,
                ) {
                  return Card(
                    child: Column(
                      children: <Widget>[
                        _languageTile(
                          language: AppLanguage.turkish,
                          selectedLanguage: selectedLanguage,
                          title: l10n.turkish,
                          subtitle: 'Türkçe',
                          flag: '🇹🇷',
                        ),
                        _languageTile(
                          language: AppLanguage.english,
                          selectedLanguage: selectedLanguage,
                          title: l10n.english,
                          subtitle: 'English',
                          flag: '🇬🇧',
                        ),
                        _languageTile(
                          language: AppLanguage.german,
                          selectedLanguage: selectedLanguage,
                          title: l10n.german,
                          subtitle: 'Deutsch',
                          flag: '🇩🇪',
                        ),
                      ],
                    ),
                  );
                },
          ),
          const SizedBox(height: 16),
          _title(l10n.theme),
          Card(
            child: ValueListenableBuilder<AppThemePreference>(
              valueListenable: ThemeController.preference,
              builder:
                  (
                    BuildContext context,
                    AppThemePreference preference,
                    Widget? child,
                  ) {
                    return RadioGroup<AppThemePreference>(
                      groupValue: preference,
                      onChanged: (AppThemePreference? selected) {
                        if (selected != null) {
                          ThemeController.setPreference(selected);
                        }
                      },
                      child: Column(
                        children: AppThemePreference.values.map((
                          AppThemePreference value,
                        ) {
                          final String title;

                          switch (value) {
                            case AppThemePreference.system:
                              title = l10n.systemTheme;
                            case AppThemePreference.light:
                              title = l10n.lightTheme;
                            case AppThemePreference.dark:
                              title = l10n.darkTheme;
                          }

                          return RadioListTile<AppThemePreference>(
                            value: value,
                            title: Text(title),
                          );
                        }).toList(),
                      ),
                    );
                  },
            ),
          ),
          const SizedBox(height: 16),

          _title(
            _settingsText(context, tr: 'Destek', en: 'Support', de: 'Support'),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(
                _settingsText(
                  context,
                  tr: 'Destek Merkezi',
                  en: 'Support Center',
                  de: 'Support Center',
                ),
              ),
              subtitle: Text(
                _settingsText(
                  context,
                  tr: 'Destek taleplerini oluştur ve takip et.',
                  en: 'Create and track your support requests.',
                  de: 'Supportanfragen erstellen und verfolgen.',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportCenterScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(
                _settingsText(
                  context,
                  tr: 'Engellenen kullanıcılar',
                  en: 'Blocked users',
                  de: 'Blockierte Benutzer',
                ),
              ),
              subtitle: Text(
                _settingsText(
                  context,
                  tr: 'Engellediğin kullanıcıları görüntüle ve yönet.',
                  en: 'View and manage users you have blocked.',
                  de: 'Blockierte Benutzer anzeigen und verwalten.',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const BlockedUsersScreen(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          _title(
            _settingsText(
              context,
              tr: 'Belgeler',
              en: 'Documents',
              de: 'Dokumente',
            ),
          ),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Gizlilik Politikası',
                      en: 'Privacy Policy',
                      de: 'Datenschutzerklärung',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _document('privacy_policy'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Kullanım Koşulları',
                      en: 'Terms of Use',
                      de: 'Nutzungsbedingungen',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _document('terms_of_use'),
                ),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Topluluk Kuralları',
                      en: 'Community Rules',
                      de: 'Community-Regeln',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _document('community_rules'),
                ),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'KVKK Aydınlatma Metni',
                      en: 'KVKK Privacy Notice',
                      de: 'KVKK-Hinweis',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _document('kvkk_notice'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _title(
            _settingsText(context, tr: 'Hesap', en: 'Account', de: 'Konto'),
          ),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.phone_android_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Telefon numarasını değiştir',
                      en: 'Change phone number',
                      de: 'Telefonnummer ändern',
                    ),
                  ),
                  subtitle: Text(
                    _settingsText(
                      context,
                      tr: 'Giriş yaptığın telefon numarasını güncelle.',
                      en: 'Update the phone number you use to sign in.',
                      de: 'Aktualisiere die Telefonnummer, mit der du dich anmeldest.',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: deletionBusy
                      ? null
                      : () async {
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => const ChangePhoneScreen(),
                            ),
                          );

                          if (mounted) {
                            await _load();
                          }
                        },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: deletionBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.red,
                        ),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Hesap silme talebi oluştur',
                      en: 'Request account deletion',
                      de: 'Kontolöschung beantragen',
                    ),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    _settingsText(
                      context,
                      tr: 'Talep sonrası oturumun kapanır. Uygulamaya giremiyorsan destek@dortapp.com adresine yazabilirsin.',
                      en: 'You will be signed out after the request. If you cannot open the app, write to destek@dortapp.com.',
                      de: 'Nach dem Antrag wirst du abgemeldet. Wenn du die App nicht öffnen kannst, schreibe an destek@dortapp.com.',
                    ),
                  ),
                  onTap: deletionBusy ? null : _requestAccountDeletion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageTile({
    required AppLanguage language,
    required AppLanguage selectedLanguage,
    required String title,
    required String subtitle,
    required String flag,
  }) {
    final bool selected = language == selectedLanguage;

    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 26)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: title == subtitle ? null : Text(subtitle),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.circle_outlined),
      onTap: selected ? null : () => _changeLanguage(language),
    );
  }

  Widget _title(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}
