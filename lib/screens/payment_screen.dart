import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/event_model.dart';

String _paymentText(
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

class PaymentScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> initialData;

  const PaymentScreen({
    super.key,
    required this.eventId,
    required this.initialData,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _busy = false;
  bool _agreementAccepted = false;

  DocumentReference<Map<String, dynamic>> get _eventRef =>
      FirebaseFirestore.instance.collection('events').doc(widget.eventId);

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

  Future<void> _confirmPayment(Map<String, dynamic> data) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || _busy) {
      return;
    }

    final String creatorUid =
        data['olusturanUid']?.toString() ??
        data['creatorUid']?.toString() ??
        '';

    if (creatorUid != user.uid) {
      _showMessage(_paymentText(context, tr: 'Yalnızca etkinlik sahibi ödeme işlemini başlatabilir.', en: 'Only the event organizer can start payment.', de: 'Nur der Veranstalter kann die Zahlung starten.'));
      return;
    }

    if (!_agreementAccepted) {
      _showMessage(_paymentText(context, tr: 'Devam etmek için sözleşmeyi onaylamalısın.', en: 'You must accept the agreement to continue.', de: 'Du musst der Vereinbarung zustimmen, um fortzufahren.'));
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('startPayment');

      final HttpsCallableResult<dynamic> result = await callable.call(
        <String, dynamic>{'eventId': widget.eventId},
      );

      if (!mounted) return;

      final Map<String, dynamic> payload =
          Map<String, dynamic>.from(
            (result.data as Map?) ?? const <String, dynamic>{},
          );

      final String checkoutUrl =
          payload['checkoutUrl']?.toString().trim() ?? '';

      if (checkoutUrl.isEmpty) {
        _showMessage(
          _paymentText(context, tr: 'Ödeme bağlantısı henüz hazır değil. Lütfen daha sonra tekrar dene.', en: 'The payment link is not ready yet. Please try again later.', de: 'Der Zahlungslink ist noch nicht bereit. Bitte versuche es später erneut.'),
        );
        return;
      }

      final Uri? uri = Uri.tryParse(checkoutUrl);

      if (uri == null || uri.scheme != 'https') {
        _showMessage(_paymentText(context, tr: 'Güvenli ödeme bağlantısı oluşturulamadı.', en: 'The secure payment link could not be created.', de: 'Der sichere Zahlungslink konnte nicht erstellt werden.'));
        return;
      }

      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;
      if (!opened) {
        _showMessage(_paymentText(context, tr: 'Ödeme sayfası açılamadı.', en: 'The payment page could not be opened.', de: 'Die Zahlungsseite konnte nicht geöffnet werden.'));
      }
    } on StateError catch (error) {
      _showMessage(error.message.toString());
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showMessage(error.message ?? _paymentText(context, tr: 'Ödeme işlemi başlatılamadı.', en: 'Payment could not be started.', de: 'Die Zahlung konnte nicht gestartet werden.'));
    } catch (_) {
      if (!mounted) return;
      _showMessage(_paymentText(context, tr: 'Ödeme işlemi başlatılamadı.', en: 'Payment could not be started.', de: 'Die Zahlung konnte nicht gestartet werden.'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _cleanGameName(String value) {
    return value.replaceFirst(RegExp(r'^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+\s*'), '');
  }

  String _gameEmoji(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '🎯';
    }

    final String first = trimmed.split(' ').first;
    final bool looksLikeEmoji = !RegExp(
      r'[A-Za-zÇĞİÖŞÜçğıöşü0-9]',
    ).hasMatch(first);

    return looksLikeEmoji ? first : '🎯';
  }

  Color _gameColor(String value) {
    final String normalized = value.toLowerCase();

    if (normalized.contains('futbol')) {
      return const Color(0xff2E7D32);
    }
    if (normalized.contains('basket')) {
      return const Color(0xffF57C00);
    }
    if (normalized.contains('tenis')) {
      return const Color(0xff1976D2);
    }
    if (normalized.contains('batak')) {
      return const Color(0xff111827);
    }
    if (normalized.contains('voley')) {
      return const Color(0xff7B1FA2);
    }
    if (normalized.contains('bilardo')) {
      return const Color(0xff00695C);
    }
    if (normalized.contains('bowling')) {
      return const Color(0xffC2185B);
    }
    if (normalized.contains('okey')) {
      return const Color(0xffD97706);
    }

    return const Color(0xffFF9800);
  }

  String _formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: value.toDouble() == value.toInt() ? 0 : 2,
    ).format(value);
  }

  String _paymentStatusLabel(Map<String, dynamic> data) {
    final String status = data['paymentStatus']?.toString().toLowerCase() ?? '';

    if (<String>{
      'paid',
      'completed',
      'success',
      'succeeded',
    }.contains(status)) {
      return _paymentText(context, tr: 'Ödeme tamamlandı', en: 'Payment completed', de: 'Zahlung abgeschlossen');
    }

    if (<String>{
      'payment_pending',
      'paymentpending',
      'pending',
    }.contains(status)) {
      return _paymentText(context, tr: 'Ödeme bekleniyor', en: 'Payment pending', de: 'Zahlung ausstehend');
    }

    if (<String>{'failed', 'cancelled', 'canceled'}.contains(status)) {
      return _paymentText(context, tr: 'Ödeme başarısız', en: 'Payment failed', de: 'Zahlung fehlgeschlagen');
    }

    return _paymentText(context, tr: 'Ödeme hazırlanıyor', en: 'Preparing payment', de: 'Zahlung wird vorbereitet');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _eventRef.snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? widget.initialData;

            final EventModel event = EventModel.fromMap(
              data,
              documentId: widget.eventId,
            );

            final String gameName = _cleanGameName(event.resolvedGameName);
            final String categoryName = event.resolvedCategoryName;
            final DateTime startAt = event.resolvedStartAt;
            final int playerCount = event.playerCount;
            final num total = event.resolvedCustomerTotal;
            final Color gameColor = _gameColor(event.resolvedGameName);
            final String paymentStatus = _paymentStatusLabel(data);

            return Scaffold(
              appBar: AppBar(title: const Text('Ödeme'), centerTitle: true),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            gameColor,
                            gameColor.withValues(alpha: 0.72),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _gameEmoji(event.resolvedGameName),
                              style: const TextStyle(fontSize: 34),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  gameName.isEmpty ? 'Etkinlik' : gameName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                if (categoryName.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    categoryName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildStatusCard(context, paymentStatus),
                    const SizedBox(height: 14),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _paymentText(context, tr: 'Ödeme özeti', en: 'Payment summary', de: 'Zahlungsübersicht'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 18),
                            _summaryRow(
                              context,
                              icon: Icons.calendar_month_outlined,
                              label: 'Tarih ve saat',
                              value: DateFormat(
                                'dd.MM.yyyy • HH:mm',
                              ).format(startAt),
                            ),
                            _summaryRow(
                              context,
                              icon: Icons.timelapse_outlined,
                              label: _paymentText(context, tr: 'Süre', en: 'Duration', de: 'Dauer'),
                              value: event.durationText,
                            ),
                            _summaryRow(
                              context,
                              icon: Icons.groups_outlined,
                              label: _paymentText(context, tr: 'Oyuncu sayısı', en: 'Player count', de: 'Spieleranzahl'),
                              value: '$playerCount',
                            ),
                            _summaryRow(
                              context,
                              icon: Icons.sell_outlined,
                              label: _paymentText(context, tr: 'Kategori taban fiyatı', en: 'Category base price', de: 'Kategorie-Grundpreis'),
                              value:
                                  '${_formatMoney(event.resolvedBasePricePerPlayer)} / oyuncu',
                            ),
                            const Divider(height: 28),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'Toplam tutar',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  _formatMoney(total),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSecurityCard(context),
                    const SizedBox(height: 14),
                    Card(
                      margin: EdgeInsets.zero,
                      child: CheckboxListTile(
                        value: _agreementAccepted,
                        onChanged: _busy
                            ? null
                            : (bool? value) {
                                setState(() {
                                  _agreementAccepted = value ?? false;
                                });
                              },
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          _paymentText(context, tr: 'Hizmet ve iptal koşullarını okudum, kabul ediyorum.', en: 'I have read and accept the service and cancellation terms.', de: 'Ich habe die Service- und Stornobedingungen gelesen und akzeptiere sie.'),
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          _paymentText(context, tr: 'Ödeme yalnızca güvenli ödeme sağlayıcısının sayfasında tamamlanır.', en: 'Payment is completed only on the secure payment provider page.', de: 'Die Zahlung wird ausschließlich auf der sicheren Seite des Zahlungsanbieters abgeschlossen.'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _confirmPayment(data),
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _busy ? _paymentText(context, tr: 'İşlem yapılıyor...', en: 'Processing...', de: 'Wird verarbeitet...') : _paymentText(context, tr: 'Ödemeyi Onayla', en: 'Confirm Payment', de: 'Zahlung bestätigen'),
                    ),
                  ),
                ),
              ),
            );
          },
    );
  }

  Widget _buildStatusCard(BuildContext context, String status) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.verified_user_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _paymentText(context, tr: 'Güvenli ödeme', en: 'Secure payment', de: 'Sichere Zahlung'),
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  _paymentText(context, tr: 'Ödeme emanet hesapta tutulur. Etkinlik sonucu netleşmeden ödeme oyunculara aktarılmaz.', en: 'Payment is held securely and is not transferred before the event outcome is finalized.', de: 'Die Zahlung wird sicher verwahrt und erst nach Abschluss der Veranstaltung weitergeleitet.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
