import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_panel_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/language_controller.dart';
import '../services/session_service.dart';
import '../services/theme_controller.dart';
import 'change_phone_screen.dart';
import 'legal_document_screen.dart';
import 'login_screen.dart';
import 'support_center_screen.dart';

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
  bool loading = true;
  bool deletionBusy = false;
  bool isAdmin = false;

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
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final Map<String, dynamic> userData =
          document.data() ?? <String, dynamic>{};

      final Map<String, dynamic> preferences = Map<String, dynamic>.from(
        userData['bildirimAyarlari'] ?? const <String, dynamic>{},
      );

      if (!mounted) {
        return;
      }

      final IdTokenResult tokenResult =
      await user!.getIdTokenResult(true);

      final Map<String, dynamic> claims =
          tokenResult.claims ?? <String, dynamic>{};

      final String role =
          claims['role']?.toString().toLowerCase() ?? '';

      final bool adminFromClaims =
          claims['admin'] == true ||
              role == 'admin' ||
              role == 'super_admin' ||
              role == 'moderator';
      setState(() {
        messages = preferences['mesajlar'] ?? true;
        events = preferences['etkinlikler'] ?? true;
        applications = preferences['basvurular'] ?? true;
        campaigns = preferences['kampanyalar'] ?? false;
        isAdmin = adminFromClaims;
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
        'bildirimAyarlari': <String, bool>{
          'mesajlar': messages,
          'etkinlikler': events,
          'basvurular': applications,
          'kampanyalar': campaigns,
        },
      },
      SetOptions(merge: true),
    );
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
          content: Text(
            _settingsText(
              dialogContext,
              tr: 'Hesabın hemen silinmez. Silme talebin kaydedilir ve işlem tamamlanana kadar hesabını kullanamazsın.',
              en: 'Your account will not be deleted immediately. Your request will be recorded, and you will not be able to use your account until the process is completed.',
              de: 'Dein Konto wird nicht sofort gelöscht. Der Antrag wird gespeichert und du kannst dein Konto bis zum Abschluss nicht verwenden.',
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
      final HttpsCallable callable =
          FirebaseFunctions.instanceFor(
            region: 'europe-west1',
          ).httpsCallable('requestAccountDeletion');

      await callable.call();

      await SessionService.clearSession();
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
              ],
            ),
          ),
          const SizedBox(height: 22),
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
          const SizedBox(height: 22),
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
          const SizedBox(height: 22),

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

          if (isAdmin) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_outlined,
                ),
                title: Text(
                  _settingsText(
                    context,
                    tr: 'Yönetim Paneli',
                    en: 'Admin Panel',
                    de: 'Administrationsbereich',
                  ),
                ),
                subtitle: Text(
                  _settingsText(
                    context,
                    tr: 'Kullanıcıları, etkinlikleri ve sistemi yönet.',
                    en: 'Manage users, events and system operations.',
                    de: 'Benutzer, Veranstaltungen und System verwalten.',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return const AdminPanelScreen();
                      },
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 22),

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
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Kullanım Koşulları',
                      en: 'Terms of Service',
                      de: 'Nutzungsbedingungen',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _document('terms_of_service'),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Gizlilik Politikası',
                      en: 'Privacy Policy',
                      de: 'Datenschutzrichtlinie',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _document('kvkk_notice'),
                ),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(
                    _settingsText(
                      context,
                      tr: 'Topluluk Kuralları',
                      en: 'Community Guidelines',
                      de: 'Community-Richtlinien',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _document('terms_of_service'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
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
                            setState(() {});
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
                      tr: 'Talep sonrası oturumun kapanır ve hesabın incelemeye alınır.',
                      en: 'You will be signed out and your account will be reviewed.',
                      de: 'Du wirst abgemeldet und dein Konto wird überprüft.',
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
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}
