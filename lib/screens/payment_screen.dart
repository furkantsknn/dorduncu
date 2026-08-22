import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';

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
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
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
      _showMessage('Yalnızca etkinlik sahibi ödeme işlemini başlatabilir.');
      return;
    }

    if (!_agreementAccepted) {
      _showMessage('Devam etmek için sözleşmeyi onaylamalısın.');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await FirebaseFirestore.instance.runTransaction<void>((transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await transaction.get(_eventRef);

        final Map<String, dynamic>? latestData = snapshot.data();

        if (!snapshot.exists || latestData == null) {
          throw StateError('Etkinlik bulunamadı.');
        }

        final String latestCreatorUid =
            latestData['olusturanUid']?.toString() ??
                latestData['creatorUid']?.toString() ??
                '';

        if (latestCreatorUid != user.uid) {
          throw StateError(
            'Yalnızca etkinlik sahibi ödeme işlemini başlatabilir.',
          );
        }

        final String paymentStatus =
            latestData['paymentStatus']?.toString().toLowerCase() ?? '';

        if (<String>{
          'paid',
          'completed',
          'success',
          'succeeded',
        }.contains(paymentStatus)) {
          throw StateError('Bu etkinliğin ödemesi zaten tamamlanmış.');
        }

        transaction.set(
          _eventRef,
          <String, dynamic>{
            'paymentStatus': 'payment_pending',
            'paymentRequired': true,
            'paymentInitiatedBy': user.uid,
            'paymentInitiatedAt': FieldValue.serverTimestamp(),
            'durum': 'odeme_bekliyor',
            'status': 'payment_pending',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      _showMessage(
        'Ödeme talebi oluşturuldu. Gerçek ödeme altyapısı bağlandığında işlem burada tamamlanacak.',
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on StateError catch (error) {
      _showMessage(error.message.toString());
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ?? 'Ödeme işlemi başlatılamadı.',
      );
    } catch (_) {
      _showMessage('Ödeme işlemi başlatılamadı.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _cleanGameName(String value) {
    return value.replaceFirst(
      RegExp(r'^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+\s*'),
      '',
    );
  }

  String _gameEmoji(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '🎯';
    }

    final String first = trimmed.split(' ').first;
    final bool looksLikeEmoji =
    !RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü0-9]').hasMatch(first);

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
    final String status =
        data['paymentStatus']?.toString().toLowerCase() ?? '';

    if (<String>{'paid', 'completed', 'success', 'succeeded'}
        .contains(status)) {
      return 'Ödeme tamamlandı';
    }

    if (<String>{'payment_pending', 'paymentpending', 'pending'}
        .contains(status)) {
      return 'Ödeme bekleniyor';
    }

    if (<String>{'failed', 'cancelled', 'canceled'}.contains(status)) {
      return 'Ödeme başarısız';
    }

    return 'Ödeme hazırlanıyor';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _eventRef.snapshots(),
      builder: (
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
          appBar: AppBar(
            title: const Text('Ödeme'),
            centerTitle: true,
          ),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
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
                                  color: Colors.white.withValues(alpha: 0.88),
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
                          'Ödeme özeti',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 18),
                        _summaryRow(
                          context,
                          icon: Icons.calendar_month_outlined,
                          label: 'Tarih ve saat',
                          value: DateFormat('dd.MM.yyyy • HH:mm').format(startAt),
                        ),
                        _summaryRow(
                          context,
                          icon: Icons.timelapse_outlined,
                          label: 'Süre',
                          value: event.durationText,
                        ),
                        _summaryRow(
                          context,
                          icon: Icons.groups_outlined,
                          label: 'Oyuncu sayısı',
                          value: '$playerCount',
                        ),
                        _summaryRow(
                          context,
                          icon: Icons.sell_outlined,
                          label: 'Kategori taban fiyatı',
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
                    title: const Text(
                      'Hizmet ve iptal koşullarını okudum, kabul ediyorum.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Gerçek ödeme sağlayıcısı bağlanana kadar bu işlem yalnızca ödeme talebini oluşturur.',
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
                  _busy ? 'İşlem yapılıyor...' : 'Ödemeyi Onayla',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(
      BuildContext context,
      String status,
      ) {
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
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.verified_user_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Güvenli ödeme',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Ödeme emanet hesapta tutulur. Etkinlik sonucu netleşmeden ödeme oyunculara aktarılmaz.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
