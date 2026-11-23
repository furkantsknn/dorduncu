import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../legal/legal_service.dart';
import '../legal/login_legal_consent.dart';
import '../services/language_controller.dart';
import '../services/session_service.dart';
import 'legal_document_screen.dart';

class LegalAcceptanceScreen extends StatefulWidget {
  const LegalAcceptanceScreen({
    super.key,
    this.initiallyConfirmed = false,
    this.userIdProvider,
    this.sessionIdProvider,
    this.bindingChanges,
    this.recorder,
    this.signOut,
    this.onCompleted,
    this.requestTimeout = const Duration(seconds: 20),
  });

  final bool initiallyConfirmed;
  final String? Function()? userIdProvider;
  final String? Function()? sessionIdProvider;
  final Stream<String?>? bindingChanges;
  final Future<void> Function(String userId, String locale)? recorder;
  final Future<void> Function()? signOut;
  final VoidCallback? onCompleted;
  final Duration requestTimeout;

  @override
  State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  late bool _termsAccepted = widget.initiallyConfirmed;
  late bool _ageDeclared = widget.initiallyConfirmed;
  bool _saving = false;
  bool _requestInFlight = false;
  String? _error;
  String? _bindingKey;
  AuthSessionBinding? _authBinding;
  StreamSubscription<dynamic>? _bindingSubscription;
  int _operationToken = 0;

  _AcceptanceText get text =>
      _AcceptanceText(LanguageController.language.value);

  @override
  void initState() {
    super.initState();
    if (widget.userIdProvider != null) {
      _bindingKey = _testBindingKey();
      _bindingSubscription = widget.bindingChanges?.listen(_bindingChanged);
    } else {
      unawaited(_captureProductionBinding(resetChoices: false));
      _bindingSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (_) => _captureProductionBinding(resetChoices: true),
      );
    }
  }

  String? _testBindingKey() {
    final String? uid = widget.userIdProvider?.call();
    final String session = widget.sessionIdProvider?.call() ?? 'test';
    return uid == null ? null : '$uid:$session';
  }

  Future<void> _captureProductionBinding({required bool resetChoices}) async {
    final AuthSessionBinding? binding =
        await SessionService.captureAuthSession();
    if (!mounted) return;
    _authBinding = binding;
    if (resetChoices) {
      _bindingChanged(binding?.key);
    } else {
      setState(() => _bindingKey = binding?.key);
    }
  }

  void _bindingChanged(String? binding) {
    if (!mounted || binding == _bindingKey) return;
    setState(() {
      _bindingKey = binding;
      _operationToken++;
      _termsAccepted = false;
      _ageDeclared = false;
      _saving = false;
      _requestInFlight = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    final String? uid =
        widget.userIdProvider?.call() ?? FirebaseAuth.instance.currentUser?.uid;
    final String? binding = widget.userIdProvider != null
        ? _testBindingKey()
        : _authBinding?.key;
    if (_saving || _requestInFlight || uid == null || binding == null) return;
    if (binding != _bindingKey) {
      _bindingChanged(binding);
      return;
    }
    if (!_termsAccepted || !_ageDeclared) {
      setState(() => _error = text.required);
      return;
    }
    setState(() {
      _saving = true;
      _requestInFlight = true;
      _error = null;
    });
    final int token = ++_operationToken;
    late final Future<void> operation;
    try {
      final String locale = LanguageController.locale.value.languageCode;
      operation =
          widget.recorder?.call(uid, locale) ??
          LegalService.recordOnboardingAcceptances(userId: uid, locale: locale);
      await operation.timeout(widget.requestTimeout);
      if (!await _isCurrentOperation(token, binding)) return;
      if (!mounted) return;
      if (widget.onCompleted != null) {
        widget.onCompleted!();
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } on TimeoutException {
      if (!await _isCurrentOperation(token, binding)) return;
      setState(() {
        _saving = false;
        _error = text.timedOut;
      });
      unawaited(
        operation.then(
          (_) => _finishLateOperation(token, binding),
          onError: (_) => _finishLateOperation(token, binding),
        ),
      );
    } catch (_) {
      if (!await _isCurrentOperation(token, binding)) return;
      setState(() {
        _saving = false;
        _requestInFlight = false;
        _error = text.saveFailed;
      });
    }
  }

  Future<bool> _isCurrentOperation(int token, String binding) async {
    if (!mounted || token != _operationToken || binding != _bindingKey) {
      return false;
    }
    if (widget.userIdProvider != null) {
      return binding == _testBindingKey();
    }
    final AuthSessionBinding? authBinding = _authBinding;
    return authBinding != null &&
        authBinding.key == binding &&
        await SessionService.isAuthSessionCurrent(authBinding);
  }

  Future<void> _finishLateOperation(int token, String binding) async {
    if (!await _isCurrentOperation(token, binding)) return;
    setState(() {
      _requestInFlight = false;
      _error = text.finishedAfterTimeout;
    });
  }

  Future<void> _signOut() async {
    _operationToken++;
    setState(() {
      _saving = false;
      _requestInFlight = false;
    });
    await (widget.signOut?.call() ?? FirebaseAuth.instance.signOut());
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  void dispose() {
    _bindingSubscription?.cancel();
    super.dispose();
  }

  void _openDocument(String code) {
    final document = LegalService.getDocumentByCode(code);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            LegalDocumentScreen(documentCode: code, title: document.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(text.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(text.description),
            const SizedBox(height: 20),
            LoginLegalConsent(
              termsAccepted: _termsAccepted,
              ageDeclared: _ageDeclared,
              language: LanguageController.language.value,
              onTermsChanged: _saving
                  ? (_) {}
                  : (value) => setState(() => _termsAccepted = value),
              onAgeChanged: _saving
                  ? (_) {}
                  : (value) => setState(() => _ageDeclared = value),
              onOpenDocument: _openDocument,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || _requestInFlight ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(text.retry),
            ),
            TextButton(onPressed: _signOut, child: Text(text.signOut)),
          ],
        ),
      ),
    );
  }
}

class _AcceptanceText {
  const _AcceptanceText(this.language);
  final AppLanguage language;
  String _v(String tr, String en, String de) => switch (language) {
    AppLanguage.turkish => tr,
    AppLanguage.english => en,
    AppLanguage.german => de,
  };
  String get title => _v(
    'Kabul kaydı gerekli',
    'Acceptance required',
    'Zustimmung erforderlich',
  );
  String get description => _v(
    'Devam etmek için zorunlu kabullerin sunucuya kaydedilmesi gerekir.',
    'Your required acceptances must be saved before you can continue.',
    'Deine erforderlichen Zustimmungen müssen vor dem Fortfahren gespeichert werden.',
  );
  String get required => _v(
    'İki zorunlu kutuyu işaretleyin.',
    'Select both required boxes.',
    'Wähle beide erforderlichen Kästchen aus.',
  );
  String get saveFailed => _v(
    'Kabul kaydı kaydedilemedi. Bağlantınızı kontrol edip tekrar deneyin veya güvenli şekilde çıkış yapın.',
    'Your acceptance could not be saved. Check your connection and retry, or sign out safely.',
    'Deine Zustimmung konnte nicht gespeichert werden. Prüfe die Verbindung und versuche es erneut oder melde dich sicher ab.',
  );
  String get timedOut => _v(
    'Kayıt beklenenden uzun sürüyor. Güvenli çıkış yapabilirsiniz; yeni bir kayıt isteği başlatılmadı.',
    'Saving is taking longer than expected. You can sign out safely; no second save was started.',
    'Das Speichern dauert länger als erwartet. Du kannst dich sicher abmelden; es wurde kein zweiter Speichervorgang gestartet.',
  );
  String get finishedAfterTimeout => _v(
    'Önceki istek sonuçlandı. Sunucu kaydını doğrulamak için tekrar deneyin.',
    'The previous request finished. Retry to verify the server record.',
    'Die vorherige Anfrage ist abgeschlossen. Versuche es erneut, um den Servereintrag zu prüfen.',
  );
  String get retry =>
      _v('Kaydet ve devam et', 'Save and continue', 'Speichern und fortfahren');
  String get signOut =>
      _v('Güvenli çıkış', 'Sign out safely', 'Sicher abmelden');
}
