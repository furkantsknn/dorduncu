import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../legal/legal_service.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.documentCode,
    this.title,
  });

  final String documentCode;
  final String? title;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  Future<String>? _documentFuture;
  String? _loadedLanguageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final String languageCode = Localizations.localeOf(context).languageCode;

    if (_documentFuture == null || _loadedLanguageCode != languageCode) {
      _loadedLanguageCode = languageCode;
      _documentFuture = _loadDocument();
    }
  }

  @override
  void didUpdateWidget(covariant LegalDocumentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.documentCode != widget.documentCode) {
      _documentFuture = _loadDocument();
    }
  }

  Future<String> _loadDocument() {
    final String languageCode = Localizations.localeOf(context).languageCode;

    return LegalService.loadDocumentByCode(
      documentCode: widget.documentCode,
      languageCode: languageCode,
    );
  }

  void _retry() {
    setState(() {
      _documentFuture = _loadDocument();
    });
  }

  String _screenTitle(BuildContext context) {
    final String? customTitle = widget.title?.trim();

    if (customTitle != null && customTitle.isNotEmpty) {
      return customTitle;
    }

    final String languageCode = LegalService.normalizeLanguageCode(
      Localizations.localeOf(context).languageCode,
    );

    switch (widget.documentCode) {
      case 'kvkk_notice':
        switch (languageCode) {
          case 'en':
            return 'KVKK Privacy Notice';
          case 'de':
            return 'KVKK-Hinweis';
          default:
            return 'KVKK Aydınlatma Metni';
        }
      case 'privacy_policy':
        switch (languageCode) {
          case 'en':
            return 'Privacy Policy';
          case 'de':
            return 'Datenschutzerklärung';
          default:
            return 'Gizlilik Politikası';
        }
      case 'terms_of_use':
        switch (languageCode) {
          case 'en':
            return 'Terms of Use';
          case 'de':
            return 'Nutzungsbedingungen';
          default:
            return 'Kullanım Koşulları';
        }
      case 'community_rules':
        switch (languageCode) {
          case 'en':
            return 'Community Rules';
          case 'de':
            return 'Community-Regeln';
          default:
            return 'Topluluk Kuralları';
        }
      case 'plus_subscription':
        switch (languageCode) {
          case 'en':
            return 'Plus Subscription Terms';
          case 'de':
            return 'Plus-Abonnementbedingungen';
          default:
            return 'Plus Abonelik Koşulları';
        }
      case 'automatic_renewal':
        switch (languageCode) {
          case 'en':
            return 'Automatic Renewal';
          case 'de':
            return 'Automatische Verlängerung';
          default:
            return 'Otomatik Yenileme';
        }
      case 'digital_products':
        switch (languageCode) {
          case 'en':
            return 'Digital Product Terms';
          case 'de':
            return 'Digitale Produkte';
          default:
            return 'Dijital Ürün Koşulları';
        }
      default:
        switch (languageCode) {
          case 'en':
            return 'Legal Document';
          case 'de':
            return 'Rechtliches Dokument';
          default:
            return 'Hukuki Belge';
        }
    }
  }

  String _loadingText(BuildContext context) {
    final String languageCode = LegalService.normalizeLanguageCode(
      Localizations.localeOf(context).languageCode,
    );

    switch (languageCode) {
      case 'en':
        return 'Document is loading...';
      case 'de':
        return 'Dokument wird geladen...';
      default:
        return 'Belge yükleniyor...';
    }
  }

  String _errorTitle(BuildContext context) {
    final String languageCode = LegalService.normalizeLanguageCode(
      Localizations.localeOf(context).languageCode,
    );

    switch (languageCode) {
      case 'en':
        return 'Document could not be loaded';
      case 'de':
        return 'Dokument konnte nicht geladen werden';
      default:
        return 'Belge yüklenemedi';
    }
  }

  String _errorDescription(BuildContext context) {
    final String languageCode = LegalService.normalizeLanguageCode(
      Localizations.localeOf(context).languageCode,
    );

    switch (languageCode) {
      case 'en':
        return 'Please check the asset file and try again.';
      case 'de':
        return 'Bitte prüfen Sie die Asset-Datei und versuchen Sie es erneut.';
      default:
        return 'Lütfen belge dosyasını kontrol edip yeniden deneyin.';
    }
  }

  String _retryText(BuildContext context) {
    final String languageCode = LegalService.normalizeLanguageCode(
      Localizations.localeOf(context).languageCode,
    );

    switch (languageCode) {
      case 'en':
        return 'Try again';
      case 'de':
        return 'Erneut versuchen';
      default:
        return 'Tekrar dene';
    }
  }

  String _versionText(BuildContext context) {
    final document = LegalService.getDocumentByCode(widget.documentCode);

    final String languageCode = LegalService.normalizeLanguageCode(
      Localizations.localeOf(context).languageCode,
    );

    switch (languageCode) {
      case 'en':
        return 'Version ${document.version}';
      case 'de':
        return 'Version ${document.version}';
      default:
        return 'Sürüm ${document.version}';
    }
  }

  MarkdownStyleSheet _markdownStyleSheet(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return MarkdownStyleSheet(
      p: textTheme.bodyMedium?.copyWith(
        height: 1.55,
        color: colorScheme.onSurface,
      ),
      h1: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: colorScheme.onSurface,
      ),
      h2: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: colorScheme.onSurface,
      ),
      h3: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: colorScheme.onSurface,
      ),
      strong: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      em: textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: colorScheme.onSurface,
      ),
      listBullet: textTheme.bodyMedium?.copyWith(
        height: 1.55,
        color: colorScheme.onSurface,
      ),
      blockquote: textTheme.bodyMedium?.copyWith(
        height: 1.5,
        color: colorScheme.onSurfaceVariant,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
      ),
      blockquotePadding: const EdgeInsets.all(12),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      tableHead: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      tableBody: textTheme.bodySmall?.copyWith(
        height: 1.4,
        color: colorScheme.onSurface,
      ),
      tableBorder: TableBorder.all(color: colorScheme.outlineVariant),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.all(10),
      code: textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        color: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      a: textTheme.bodyMedium?.copyWith(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle(context)), centerTitle: false),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Text(
                _versionText(context),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<String>(
                future: _documentFuture,
                builder:
                    (BuildContext context, AsyncSnapshot<String> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _LoadingView(message: _loadingText(context));
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.trim().isEmpty) {
                        return _ErrorView(
                          title: _errorTitle(context),
                          description: _errorDescription(context),
                          retryText: _retryText(context),
                          onRetry: _retry,
                        );
                      }

                      return Markdown(
                        data: snapshot.data!,
                        selectable: true,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        styleSheet: _markdownStyleSheet(context),
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.title,
    required this.description,
    required this.retryText,
    required this.onRetry,
  });

  final String title;
  final String description;
  final String retryText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.description_outlined,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
