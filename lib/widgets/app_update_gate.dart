import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import '../services/digital_purchase_service.dart';
import '../services/phone_verification_session.dart';

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child, required this.navigatorKey});
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> with WidgetsBindingObserver {
  UpdateDecision _decision = UpdateDecision.none;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check(force: _decision.urgency == UpdateUrgency.required);
    }
  }

  bool get _interruptionUnsafe =>
      PhoneVerificationGate.codeEntryOpen.value ||
      DigitalPurchaseService.instance.hasOpenPurchaseAttempt ||
      DigitalPurchaseService.instance.verificationInFlight ||
      (widget.navigatorKey.currentState?.canPop() ?? false) ||
      FocusManager.instance.primaryFocus?.context?.widget is EditableText;

  Future<void> _check({bool force = false}) async {
    if (_checking || _interruptionUnsafe) return;
    _checking = true;
    try {
      final decision = await AppUpdateService.check(force: force);
      if (mounted && !_interruptionUnsafe) setState(() => _decision = decision);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppVersionPolicy? policy = _decision.policy;
    return Stack(
      children: <Widget>[
        widget.child,
        if (policy != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.72),
              child: SafeArea(
                child: Center(
                  child: _UpdateCard(
                    decision: _decision,
                    onLater: _decision.urgency == UpdateUrgency.optional
                        ? () async {
                            await AppUpdateService.defer(policy);
                            if (mounted) setState(() => _decision = UpdateDecision.none);
                          }
                        : null,
                    onUpdate: () => AppUpdateService.openUpdate(
                      policy,
                      immediate: _decision.urgency == UpdateUrgency.required,
                    ),
                    onRetry: () => _check(force: true),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.decision, required this.onLater, required this.onUpdate, required this.onRetry});
  final UpdateDecision decision;
  final VoidCallback? onLater;
  final Future<bool> Function() onUpdate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final policy = decision.policy!;
    final String language = Localizations.localeOf(context).languageCode;
    final String message = policy.messages[language]?.trim().isNotEmpty == true
        ? policy.messages[language]!
        : _text(language, tr: 'Dört.’ün yeni sürümü hazır.', en: 'A new version of Dört. is available.', de: 'Eine neue Version von Dört. ist verfügbar.');
    final bool required = decision.urgency == UpdateUrgency.required;
    return Card(
      margin: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(required ? Icons.system_security_update_warning_rounded : Icons.system_update_rounded, size: 54, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(_text(language, tr: required ? 'Güncelleme gerekli' : 'Güncelleme hazır', en: required ? 'Update required' : 'Update available', de: required ? 'Update erforderlich' : 'Update verfügbar'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onUpdate, icon: const Icon(Icons.open_in_new_rounded), label: Text(_text(language, tr: 'Güncelle', en: 'Update', de: 'Aktualisieren')))),
              if (onLater != null) ...<Widget>[
                const SizedBox(height: 8),
                TextButton(onPressed: onLater, child: Text(_text(language, tr: 'Daha sonra', en: 'Later', de: 'Später'))),
              ] else ...<Widget>[
                const SizedBox(height: 8),
                TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(_text(language, tr: 'Tekrar kontrol et', en: 'Check again', de: 'Erneut prüfen'))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _text(String language, {required String tr, required String en, required String de}) {
  return switch (language) {'en' => en, 'de' => de, _ => tr};
}
