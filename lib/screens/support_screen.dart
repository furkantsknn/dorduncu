import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/support_service.dart';
import '../utils/support_categories.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.accountStatus,
  });

  final String accountStatus;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final String _clientRequestId =
      '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
  final TextEditingController messageController = TextEditingController();

  static const List<String> _categoryValues = [
    'Hesabım askıya alındı',
    'Hesabım engellendi',
    'Giriş yapamıyorum',
    'Hesap silme işlemi',
    'Diğer',
  ];

  String selectedCategory = _categoryValues.first;
  bool sending = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String _localizedText({
    required String tr,
    required String en,
    required String de,
  }) {
    final String languageCode =
    Localizations.localeOf(context).languageCode.toLowerCase();

    switch (languageCode) {
      case 'en':
        return en;
      case 'de':
        return de;
      default:
        return tr;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'Hesabım askıya alındı':
        return _localizedText(
          tr: 'Hesabım askıya alındı',
          en: 'My account was suspended',
          de: 'Mein Konto wurde gesperrt',
        );
      case 'Hesabım engellendi':
        return _localizedText(
          tr: 'Hesabım engellendi',
          en: 'My account was blocked',
          de: 'Mein Konto wurde blockiert',
        );
      case 'Giriş yapamıyorum':
        return _localizedText(
          tr: 'Giriş yapamıyorum',
          en: 'I cannot sign in',
          de: 'Ich kann mich nicht anmelden',
        );
      case 'Hesap silme işlemi':
        return _localizedText(
          tr: 'Hesap silme işlemi',
          en: 'Account deletion',
          de: 'Kontolöschung',
        );
      case 'Diğer':
        return _localizedText(
          tr: 'Diğer',
          en: 'Other',
          de: 'Andere',
        );
      default:
        return category;
    }
  }

  Future<void> _sendRequest() async {
    final String message = messageController.text.trim();

    if (message.length < 10) {
      _showMessage(
        _localizedText(
          tr: 'Lütfen sorunu en az 10 karakterle açıkla.',
          en: 'Please describe the problem using at least 10 characters.',
          de: 'Beschreibe das Problem bitte mit mindestens 10 Zeichen.',
        ),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        _localizedText(
          tr: 'Oturum bilgisi bulunamadı. Tekrar giriş yap.',
          en: 'Session information was not found. Please sign in again.',
          de: 'Sitzungsinformationen wurden nicht gefunden. Bitte melde dich erneut an.',
        ),
      );
      return;
    }

    setState(() => sending = true);

    try {
      await SupportService.createRequest(
        clientRequestId: _clientRequestId,
        category: SupportCategory.accountAppeal,
        subject: _categoryLabel(selectedCategory),
        description: message,
        urgency: SupportUrgency.normal,
      );

      if (!mounted) return;

      messageController.clear();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.supportRequestCreated),
            content: Text(
              _localizedText(
                tr: 'Talebini Destek Merkezi içindeki Destek Taleplerim bölümünden takip edebilirsin.',
                en: 'You can track your request from My Support Requests in the Support Center.',
                de: 'Du kannst deine Anfrage im Support-Center unter Meine Supportanfragen verfolgen.',
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.ok),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.code == 'permission-denied'
            ? _localizedText(
          tr: 'Destek talebi için gerekli iznin bulunmuyor.',
          en: 'You do not have permission to create this support request.',
          de: 'Du hast keine Berechtigung, diese Supportanfrage zu erstellen.',
        )
            : l10n.supportRequestCouldNotBeCreated,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(l10n.supportRequestCouldNotBeCreated);
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ??
        _localizedText(
          tr: 'Bulunamadı',
          en: 'Not found',
          de: 'Nicht gefunden',
        );

    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        title: Text(l10n.supportRequest),
        backgroundColor: const Color(0xff0F1115),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.support_agent_outlined,
                size: 72,
                color: Colors.orange,
              ),
              const SizedBox(height: 18),
              Text(
                _localizedText(
                  tr: 'Sana nasıl yardımcı olabiliriz?',
                  en: 'How can we help you?',
                  de: 'Wie können wir dir helfen?',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _localizedText(
                  tr: 'Talebini ayrıntılı yaz. Destek ekibi hesabını inceleyerek dönüş yapacaktır.',
                  en: 'Describe your request in detail. The support team will review your account and respond.',
                  de: 'Beschreibe deine Anfrage ausführlich. Das Support-Team wird dein Konto prüfen und antworten.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _InfoBox(
                label: l10n.phoneNumber,
                value: phoneNumber,
              ),
              const SizedBox(height: 12),
              _InfoBox(
                label: l10n.accountStatus,
                value: widget.accountStatus,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                dropdownColor: const Color(0xff171A20),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(l10n.supportCategory),
                items: _categoryValues
                    .map(
                      (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(_categoryLabel(category)),
                  ),
                )
                    .toList(),
                onChanged: sending
                    ? null
                    : (value) {
                  if (value != null) {
                    setState(() => selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                enabled: !sending,
                minLines: 5,
                maxLines: 9,
                maxLength: 1000,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(
                  l10n.supportDescription,
                  hint: _localizedText(
                    tr: 'Hesabının neden yanlışlıkla kısıtlandığını düşündüğünü ve yaşadığın sorunu anlat.',
                    en: 'Explain why you believe your account was restricted by mistake and describe the problem.',
                    de: 'Erkläre, warum dein Konto deiner Meinung nach irrtümlich eingeschränkt wurde, und beschreibe das Problem.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: sending ? null : _sendRequest,
                  icon: sending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    sending
                        ? _localizedText(
                      tr: 'Gönderiliyor...',
                      en: 'Sending...',
                      de: 'Wird gesendet...',
                    )
                        : l10n.submitSupportRequest,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                    Colors.orange.withValues(alpha: 0.55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xff171A20),
      counterStyle: const TextStyle(color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff171A20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
