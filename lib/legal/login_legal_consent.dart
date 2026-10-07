import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/language_controller.dart';

class LoginLegalConsent extends StatefulWidget {
  const LoginLegalConsent({
    required this.termsAccepted,
    required this.ageDeclared,
    required this.onTermsChanged,
    required this.onAgeChanged,
    required this.onOpenDocument,
    required this.language,
    this.enabled = true,
    super.key,
  });

  final bool termsAccepted;
  final bool ageDeclared;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onAgeChanged;
  final ValueChanged<String> onOpenDocument;
  final AppLanguage language;
  final bool enabled;

  @override
  State<LoginLegalConsent> createState() => _LoginLegalConsentState();
}

class _LoginLegalConsentState extends State<LoginLegalConsent> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _communityRecognizer;
  late final TapGestureRecognizer _kvkkRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _communityRecognizer = TapGestureRecognizer()..onTap = _openCommunity;
    _kvkkRecognizer = TapGestureRecognizer()..onTap = _openKvkk;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _communityRecognizer.dispose();
    _kvkkRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openTerms() => widget.onOpenDocument('terms_of_use');

  void _openCommunity() => widget.onOpenDocument('community_rules');

  void _openKvkk() => widget.onOpenDocument('kvkk_notice');

  void _openPrivacy() => widget.onOpenDocument('privacy_policy');

  @override
  Widget build(BuildContext context) {
    final _ConsentCopy copy = _ConsentCopy(widget.language);
    final TextStyle body = TextStyle(
      color: Colors.white70,
      fontSize: 13,
      height: 1.4,
    );
    final TextStyle link = body.copyWith(
      color: Colors.orange,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: Colors.orange,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ConsentCheckRow(
          value: widget.termsAccepted,
          enabled: widget.enabled,
          onChanged: widget.onTermsChanged,
          text: Text.rich(
            TextSpan(
              style: body,
              children: <InlineSpan>[
                TextSpan(text: copy.termsPrefix),
                TextSpan(
                  text: copy.termsName,
                  style: link,
                  recognizer: _termsRecognizer,
                ),
                TextSpan(text: copy.termsMiddle),
                TextSpan(
                  text: copy.communityName,
                  style: link,
                  recognizer: _communityRecognizer,
                ),
                TextSpan(text: copy.termsEnd),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ConsentCheckRow(
          value: widget.ageDeclared,
          enabled: widget.enabled,
          onChanged: widget.onAgeChanged,
          text: Text(copy.ageDeclaration, style: body),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: body,
            children: <InlineSpan>[
              TextSpan(
                text: copy.kvkkName,
                style: link,
                recognizer: _kvkkRecognizer,
              ),
              TextSpan(text: copy.informationJoiner),
              TextSpan(
                text: copy.privacyName,
                style: link,
                recognizer: _privacyRecognizer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsentCheckRow extends StatelessWidget {
  const _ConsentCheckRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.text,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Checkbox(
          value: value,
          onChanged: enabled ? (bool? next) => onChanged(next ?? false) : null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          activeColor: Colors.orange,
          checkColor: Colors.black,
          side: const BorderSide(color: Colors.white54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(padding: const EdgeInsets.only(top: 2), child: text),
        ),
      ],
    );
  }
}

class _ConsentCopy {
  const _ConsentCopy(this.language);

  final AppLanguage language;

  String _v(String tr, String en, String de) {
    switch (language) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }

  String get termsPrefix => _v('', 'I accept the ', 'Ich akzeptiere die ');

  String get termsName =>
      _v('Kullanım Koşulları', 'Terms of Use', 'Nutzungsbedingungen');

  String get termsMiddle => _v('’nı ve ', ' and the ', ' und die ');

  String get communityName =>
      _v('Topluluk Kuralları', 'Community Rules', 'Community-Regeln');

  String get termsEnd => _v('’nı kabul ediyorum.', '.', '.');

  String get ageDeclaration => _v(
    '18 yaşını doldurduğumu beyan ediyorum.',
    'I declare that I am 18 or older.',
    'Ich erkläre, dass ich das 18. Lebensjahr vollendet habe.',
  );

  String get kvkkName =>
      _v('KVKK Aydınlatma Metni', 'Personal Data Notice', 'Datenschutzhinweis');

  String get informationJoiner => _v(' ve ', ' and ', ' und ');

  String get privacyName =>
      _v('Gizlilik Politikası', 'Privacy Policy', 'Datenschutzerklärung');
}
