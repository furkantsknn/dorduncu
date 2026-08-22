import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/bank_account_service.dart';
import '../services/wallet_service.dart';
import 'bank_accounts_screen.dart';


String _walletText(
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

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const List<String> _filters = <String>[
    'all',
    'payments',
    'earnings',
    'refunds',
    'withdrawals',
  ];

  String _selectedFilter = 'all';

  int _intValue(dynamic raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _money(dynamic raw) {
    final int kurus = _intValue(raw);
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    ).format(kurus / 100);
  }

  DateTime? _date(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _typeOf(Map<String, dynamic> data) {
    return (data['type'] ??
        data['transactionType'] ??
        data['category'] ??
        '')
        .toString()
        .toLowerCase();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    if (_selectedFilter == 'all') return docs;

    return docs.where((doc) {
      final String type = _typeOf(doc.data());
      switch (_selectedFilter) {
        case 'payments':
          return type.contains('payment') ||
              type.contains('purchase') ||
              type.contains('event_payment') ||
              type.contains('customer_payment') ||
              type.contains('odeme');
        case 'earnings':
          return type.contains('earning') ||
              type.contains('payout') ||
              type.contains('player') ||
              type.contains('kazanc') ||
              type.contains('pending_credit');
        case 'refunds':
          return type.contains('refund') || type.contains('iade');
        case 'withdrawals':
          return type.contains('withdraw');
        default:
          return true;
      }
    }).toList();
  }

  String _filterLabel(BuildContext context, String filter) {
    switch (filter) {
      case 'payments':
        return _walletText(
          context,
          tr: 'Ödemeler',
          en: 'Payments',
          de: 'Zahlungen',
        );
      case 'earnings':
        return _walletText(
          context,
          tr: 'Kazançlar',
          en: 'Earnings',
          de: 'Einnahmen',
        );
      case 'refunds':
        return _walletText(
          context,
          tr: 'İadeler',
          en: 'Refunds',
          de: 'Rückerstattungen',
        );
      case 'withdrawals':
        return _walletText(
          context,
          tr: 'Çekimler',
          en: 'Withdrawals',
          de: 'Auszahlungen',
        );
      default:
        return _walletText(context, tr: 'Tümü', en: 'All', de: 'Alle');
    }
  }

  String _transactionTitle(
      BuildContext context,
      Map<String, dynamic> data,
      ) {
    final String explicit = data['title']?.toString().trim() ?? '';
    if (explicit.isNotEmpty) return explicit;

    final String type = _typeOf(data);
    if (type.contains('withdrawal_cancel')) {
      return _walletText(
        context,
        tr: 'Çekim talebi iptali',
        en: 'Withdrawal cancellation',
        de: 'Auszahlungsstornierung',
      );
    }
    if (type.contains('withdraw')) {
      return _walletText(
        context,
        tr: 'Banka hesabına aktarım',
        en: 'Bank transfer',
        de: 'Banküberweisung',
      );
    }
    if (type.contains('refund') || type.contains('iade')) {
      return _walletText(
        context,
        tr: 'Etkinlik iadesi',
        en: 'Event refund',
        de: 'Veranstaltungsrückerstattung',
      );
    }
    if (type.contains('earning') ||
        type.contains('payout') ||
        type.contains('kazanc') ||
        type.contains('pending_credit')) {
      return _walletText(
        context,
        tr: 'Oyuncu kazancı',
        en: 'Player earnings',
        de: 'Spielereinnahmen',
      );
    }
    if (type.contains('payment') ||
        type.contains('purchase') ||
        type.contains('odeme')) {
      return _walletText(
        context,
        tr: 'Etkinlik ödemesi',
        en: 'Event payment',
        de: 'Veranstaltungszahlung',
      );
    }
    if (type.contains('deposit') || type.contains('topup')) {
      return _walletText(
        context,
        tr: 'Bakiye yükleme',
        en: 'Balance top-up',
        de: 'Guthabenaufladung',
      );
    }
    return _walletText(
      context,
      tr: 'Cüzdan işlemi',
      en: 'Wallet transaction',
      de: 'Wallet-Transaktion',
    );
  }

  String _statusLabel(BuildContext context, Map<String, dynamic> data) {
    final String explicit = data['statusLabel']?.toString().trim() ?? '';
    if (explicit.isNotEmpty) return explicit;

    final String status = data['status']?.toString().toLowerCase() ?? '';
    switch (status) {
      case 'completed':
      case 'success':
      case 'paid':
      case 'released':
        return _walletText(
          context,
          tr: 'Tamamlandı',
          en: 'Completed',
          de: 'Abgeschlossen',
        );
      case 'pending':
      case 'processing':
      case 'held':
      case 'escrow':
        return _walletText(
          context,
          tr: 'Beklemede',
          en: 'Pending',
          de: 'Ausstehend',
        );
      case 'refunded':
        return _walletText(
          context,
          tr: 'İade edildi',
          en: 'Refunded',
          de: 'Erstattet',
        );
      case 'cancelled':
      case 'canceled':
        return _walletText(
          context,
          tr: 'İptal edildi',
          en: 'Cancelled',
          de: 'Storniert',
        );
      case 'failed':
      case 'rejected':
        return _walletText(
          context,
          tr: 'Başarısız',
          en: 'Failed',
          de: 'Fehlgeschlagen',
        );
      default:
        return status;
    }
  }

  IconData _transactionIcon(Map<String, dynamic> data, int amount) {
    final String type = _typeOf(data);
    if (type.contains('withdrawal_cancel')) return Icons.undo_rounded;
    if (type.contains('withdraw')) return Icons.account_balance_outlined;
    if (type.contains('refund') || type.contains('iade')) {
      return Icons.replay_circle_filled_outlined;
    }
    if (type.contains('earning') ||
        type.contains('payout') ||
        type.contains('kazanc') ||
        type.contains('pending_credit')) {
      return Icons.savings_outlined;
    }
    if (type.contains('payment') ||
        type.contains('purchase') ||
        type.contains('odeme')) {
      return Icons.credit_card_outlined;
    }
    if (type.contains('deposit') || type.contains('topup')) {
      return Icons.add_card_outlined;
    }
    return amount >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded;
  }

  Future<void> _showWithdrawSheet({
    required String uid,
    required int availableKurus,
    required bool walletFrozen,
  }) async {
    if (walletFrozen) {
      _showMessage(
        _walletText(
          context,
          tr: 'Cüzdan dondurulduğu için para çekilemez.',
          en: 'Withdrawals are unavailable while the wallet is frozen.',
          de: 'Während das Wallet gesperrt ist, sind Auszahlungen nicht möglich.',
        ),
      );
      return;
    }

    if (availableKurus <= 0) {
      _showMessage(
        _walletText(
          context,
          tr: 'Çekilebilir bakiyen bulunmuyor.',
          en: 'You do not have an available balance to withdraw.',
          de: 'Du hast kein verfügbares Guthaben zur Auszahlung.',
        ),
      );
      return;
    }

    Map<String, dynamic>? selectedAccount;

    try {
      final QuerySnapshot<Map<String, dynamic>> accountSnapshot =
      await BankAccountService.bankAccountsRef(uid)
          .orderBy('createdAt', descending: false)
          .get();

      if (accountSnapshot.docs.isNotEmpty) {
        final QueryDocumentSnapshot<Map<String, dynamic>> defaultAccount =
        accountSnapshot.docs.firstWhere(
              (document) => document.data()['isDefault'] == true,
          orElse: () => accountSnapshot.docs.first,
        );

        selectedAccount = <String, dynamic>{
          'id': defaultAccount.id,
          ...defaultAccount.data(),
        };
      }
    } catch (_) {
      selectedAccount = null;
    }

    if (!mounted) return;

    final TextEditingController amountController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool loading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> chooseAccount() async {
              final Map<String, dynamic>? account =
              await Navigator.of(sheetContext).push<Map<String, dynamic>>(
                MaterialPageRoute<Map<String, dynamic>>(
                  builder: (_) => BankAccountsScreen(
                    uid: uid,
                    selectionMode: true,
                  ),
                ),
              );

              if (account == null || !sheetContext.mounted) return;

              setSheetState(() {
                selectedAccount = account;
              });
            }

            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;

              final Map<String, dynamic>? account = selectedAccount;
              if (account == null) {
                _showMessage(
                  _walletText(
                    context,
                    tr: 'Para çekmek için bir banka hesabı seç.',
                    en: 'Select a bank account to withdraw.',
                    de: 'Wähle ein Bankkonto für die Auszahlung aus.',
                  ),
                );
                return;
              }

              final String iban = account['iban']?.toString().trim() ?? '';
              final String accountHolderName =
                  account['accountHolderName']?.toString().trim() ?? '';

              if (iban.isEmpty || accountHolderName.isEmpty) {
                _showMessage(
                  _walletText(
                    context,
                    tr: 'Seçilen banka hesabının bilgileri eksik.',
                    en: 'The selected bank account information is incomplete.',
                    de: 'Die Angaben des ausgewählten Bankkontos sind unvollständig.',
                  ),
                );
                return;
              }

              final String normalizedAmount = amountController.text
                  .trim()
                  .replaceAll('.', '')
                  .replaceAll(',', '.');
              final int amountKurus =
              ((double.tryParse(normalizedAmount) ?? 0) * 100).round();

              setSheetState(() => loading = true);

              try {
                final HttpsCallable callable =
                FirebaseFunctions.instanceFor(
                  region: 'europe-west1',
                ).httpsCallable('requestWithdrawal');

                await callable.call(<String, dynamic>{
                  'amountKurus': amountKurus,
                  'iban': iban,
                  'accountHolderName': accountHolderName,
                });

                if (!mounted || !sheetContext.mounted) return;

                Navigator.of(sheetContext).pop();
                _showMessage(
                  _walletText(
                    context,
                    tr: 'Para çekme talebi oluşturuldu.',
                    en: 'Withdrawal request created.',
                    de: 'Auszahlungsanfrage wurde erstellt.',
                  ),
                );
              } catch (error) {
                if (!mounted || !sheetContext.mounted) return;
                setSheetState(() => loading = false);
                _showMessage(error.toString());
              }
            }

            final String bankName =
                selectedAccount?['bankName']?.toString().trim() ?? '';
            final String iban =
                selectedAccount?['iban']?.toString().trim() ?? '';
            final String accountHolderName =
                selectedAccount?['accountHolderName']?.toString().trim() ?? '';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          _walletText(
                            context,
                            tr: 'Para çek',
                            en: 'Withdraw',
                            de: 'Auszahlen',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_walletText(context, tr: 'Kullanılabilir bakiye', en: 'Available balance', de: 'Verfügbares Guthaben')}: ${_money(availableKurus)}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: amountController,
                          enabled: !loading,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9,.]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: _walletText(
                              context,
                              tr: 'Tutar',
                              en: 'Amount',
                              de: 'Betrag',
                            ),
                            prefixText: '₺ ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final String normalized = (value ?? '')
                                .trim()
                                .replaceAll('.', '')
                                .replaceAll(',', '.');
                            final int amountKurus =
                            ((double.tryParse(normalized) ?? 0) * 100)
                                .round();

                            if (amountKurus <= 0) {
                              return _walletText(
                                context,
                                tr: 'Geçerli bir tutar gir.',
                                en: 'Enter a valid amount.',
                                de: 'Gib einen gültigen Betrag ein.',
                              );
                            }

                            if (amountKurus > availableKurus) {
                              return _walletText(
                                context,
                                tr: 'Tutar bakiyeden fazla olamaz.',
                                en: 'The amount cannot exceed your balance.',
                                de: 'Der Betrag darf dein Guthaben nicht überschreiten.',
                              );
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _walletText(
                            context,
                            tr: 'Banka hesabı',
                            en: 'Bank account',
                            de: 'Bankkonto',
                          ),
                          style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: loading ? null : chooseAccount,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: selectedAccount == null
                                  ? Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.add_card_outlined,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _walletText(
                                        context,
                                        tr: 'Banka hesabı ekle veya seç',
                                        en: 'Add or select a bank account',
                                        de: 'Bankkonto hinzufügen oder auswählen',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              )
                                  : Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    child: const Icon(
                                      Icons.account_balance_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          bankName.isEmpty
                                              ? _walletText(
                                            context,
                                            tr: 'Banka hesabı',
                                            en: 'Bank account',
                                            de: 'Bankkonto',
                                          )
                                              : bankName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (accountHolderName.isNotEmpty)
                                          Text(
                                            accountHolderName,
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                          ),
                                        if (iban.isNotEmpty)
                                          Text(
                                            BankAccountService.maskIban(
                                              iban,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _walletText(
                                      context,
                                      tr: 'Değiştir',
                                      en: 'Change',
                                      de: 'Ändern',
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: loading ? null : submit,
                          icon: loading
                              ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.account_balance_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              _walletText(
                                context,
                                tr: 'Talep oluştur',
                                en: 'Create request',
                                de: 'Anfrage erstellen',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh(String uid) async {
    await Future.wait<dynamic>(<Future<dynamic>>[
      WalletService.walletRef(uid).get(),
      WalletService.transactionsRef(uid).limit(1).get(),
      WalletService.withdrawalsRef(uid).limit(1).get(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_walletText(context, tr: 'Cüzdan', en: 'Wallet', de: 'Wallet')),
        ),
        body: _ErrorState(
          message: _walletText(
            context,
            tr: 'Oturum bulunamadı.',
            en: 'Session not found.',
            de: 'Sitzung nicht gefunden.',
          ),
          onRetry: () => setState(() {}),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _walletText(context, tr: 'Cüzdan', en: 'Wallet', de: 'Wallet'),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: _walletText(
              context,
              tr: 'Banka hesaplarım',
              en: 'My bank accounts',
              de: 'Meine Bankkonten',
            ),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => BankAccountsScreen(uid: uid),
                ),
              );
            },
            icon: const Icon(Icons.account_balance_outlined),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: WalletService.watchWallet(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _WalletLoadingState();
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: _walletText(
                context,
                tr: 'Cüzdan bilgileri yüklenemedi.',
                en: 'Wallet information could not be loaded.',
                de: 'Wallet-Informationen konnten nicht geladen werden.',
              ),
              onRetry: () => setState(() {}),
            );
          }

          final Map<String, dynamic> data =
              snapshot.data?.data() ?? <String, dynamic>{};
          final int available = _intValue(
            data['availableBalanceKurus'] ??
                data['availableKurus'] ??
                data['available'],
          );
          final int marketBalance = _intValue(
            data['marketBalanceKurus'] ??
                data['marketKurus'] ??
                data['marketBalance'],
          );
          final int pending = _intValue(
            data['pendingBalanceKurus'] ??
                data['pendingKurus'] ??
                data['pending'],
          );
          final int refund = _intValue(
            data['refundBalanceKurus'] ??
                data['refundKurus'] ??
                data['refund'],
          );
          final int frozen = _intValue(
            data['frozenBalanceKurus'] ??
                data['frozenKurus'] ??
                data['frozen'],
          );
          final int withdrawalPending = _intValue(
            data['withdrawalPendingKurus'] ??
                data['withdrawalPending'] ??
                data['withdrawPendingKurus'],
          );
          final bool walletFrozen = data['isFrozen'] == true;

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool tablet = constraints.maxWidth >= 760;
              final double horizontalPadding = tablet ? 28 : 16;

              return RefreshIndicator(
                onRefresh: () => _refresh(uid),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    36,
                  ),
                  children: <Widget>[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (tablet)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    flex: 3,
                                    child: _BalanceCard(
                                      availableKurus: available,
                                      marketBalance: _money(marketBalance),
                                      money: _money,
                                      pending: _money(pending),
                                      refund: _money(refund),
                                      frozen: _money(frozen),
                                      withdrawalPending: _money(withdrawalPending),
                                      walletFrozen: walletFrozen,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 2,
                                    child: _WalletActions(
                                      available: available,
                                      walletFrozen: walletFrozen,
                                      onWithdraw: () => _showWithdrawSheet(
                                        uid: uid,
                                        availableKurus: available,
                                        walletFrozen: walletFrozen,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else ...<Widget>[
                              _BalanceCard(
                                availableKurus: available,
                                marketBalance: _money(marketBalance),
                                money: _money,
                                pending: _money(pending),
                                refund: _money(refund),
                                frozen: _money(frozen),
                                withdrawalPending: _money(withdrawalPending),
                                walletFrozen: walletFrozen,
                              ),
                              const SizedBox(height: 14),
                              _WalletActions(
                                available: available,
                                walletFrozen: walletFrozen,
                                onWithdraw: () => _showWithdrawSheet(
                                  uid: uid,
                                  availableKurus: available,
                                  walletFrozen: walletFrozen,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            const _EscrowInfoCard(),
                            const SizedBox(height: 24),
                            _SectionTitle(
                              title: _walletText(
                                context,
                                tr: 'Çekim geçmişi',
                                en: 'Withdrawal history',
                                de: 'Auszahlungsverlauf',
                              ),
                              icon: Icons.account_balance_outlined,
                            ),
                            const SizedBox(height: 10),
                            _WithdrawalsSection(
                              uid: uid,
                              money: _money,
                              date: _date,
                              showMessage: _showMessage,
                            ),
                            const SizedBox(height: 24),
                            _SectionTitle(
                              title: _walletText(
                                context,
                                tr: 'Bakiyeyi nasıl kullanırsın?',
                                en: 'How can you use your balance?',
                                de: 'Wie kannst du dein Guthaben verwenden?',
                              ),
                              icon: Icons.lightbulb_outline_rounded,
                            ),
                            const SizedBox(height: 10),
                            const _WalletUsageCard(),
                            const SizedBox(height: 24),
                            _SectionTitle(
                              title: _walletText(
                                context,
                                tr: 'İşlem geçmişi',
                                en: 'Transaction history',
                                de: 'Transaktionsverlauf',
                              ),
                              icon: Icons.receipt_long_outlined,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 42,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _filters.length,
                                separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final String filter = _filters[index];
                                  return ChoiceChip(
                                    label: Text(_filterLabel(context, filter)),
                                    selected: _selectedFilter == filter,
                                    onSelected: (_) {
                                      setState(() => _selectedFilter = filter);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            _TransactionsSection(
                              uid: uid,
                              filtered: _filtered,
                              money: _money,
                              intValue: _intValue,
                              date: _date,
                              titleBuilder: (item) =>
                                  _transactionTitle(context, item),
                              statusBuilder: (item) =>
                                  _statusLabel(context, item),
                              iconBuilder: _transactionIcon,
                              filterActive: _selectedFilter != 'all',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WalletActions extends StatelessWidget {
  const _WalletActions({
    required this.available,
    required this.walletFrozen,
    required this.onWithdraw,
  });

  final int available;
  final bool walletFrozen;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 32,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              _walletText(
                context,
                tr: 'Kazancını hesabına aktar',
                en: 'Transfer earnings to your account',
                de: 'Einnahmen auf dein Konto überweisen',
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _walletText(
                context,
                tr: 'Talebin kontrol edildikten sonra banka hesabına gönderilir.',
                en: 'Your request is sent to your bank account after review.',
                de: 'Deine Anfrage wird nach Prüfung auf dein Bankkonto überwiesen.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: walletFrozen || available <= 0 ? null : onWithdraw,
              icon: const Icon(Icons.arrow_outward_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  _walletText(
                    context,
                    tr: 'Para çek',
                    en: 'Withdraw',
                    de: 'Auszahlen',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.availableKurus,
    required this.money,
    required this.marketBalance,
    required this.pending,
    required this.refund,
    required this.frozen,
    required this.withdrawalPending,
    required this.walletFrozen,
  });

  final int availableKurus;
  final String Function(dynamic raw) money;
  final String marketBalance;
  final String pending;
  final String refund;
  final String frozen;
  final String withdrawalPending;
  final bool walletFrozen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.primaryContainer,
            Color.lerp(colors.primaryContainer, colors.tertiaryContainer, 0.72)!,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wallet_rounded, color: colors.primary),
              ),
              const Spacer(),
              if (walletFrozen)
                _StatusPill(
                  text: _walletText(
                    context,
                    tr: 'Donduruldu',
                    en: 'Frozen',
                    de: 'Gesperrt',
                  ),
                  icon: Icons.lock_outline,
                  color: colors.error,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _walletText(
              context,
              tr: 'Kullanılabilir bakiye',
              en: 'Available balance',
              de: 'Verfügbares Guthaben',
            ),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: availableKurus.toDouble()),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(value.round()),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.storefront_outlined,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _walletText(
                      context,
                      tr: 'Market bakiyesi',
                      en: 'Market balance',
                      de: 'Marktguthaben',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  marketBalance,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final int columns = constraints.maxWidth < 330 ? 1 : 2;
              final List<Widget> items = <Widget>[
                _MiniBalance(
                  icon: Icons.schedule_outlined,
                  label: _walletText(
                    context,
                    tr: 'Bekleyen kazanç',
                    en: 'Pending earnings',
                    de: 'Ausstehende Einnahmen',
                  ),
                  value: pending,
                ),
                _MiniBalance(
                  icon: Icons.replay_circle_filled_outlined,
                  label: _walletText(
                    context,
                    tr: 'İade bakiyesi',
                    en: 'Refund balance',
                    de: 'Rückerstattungsguthaben',
                  ),
                  value: refund,
                ),
                _MiniBalance(
                  icon: Icons.lock_outline,
                  label: _walletText(
                    context,
                    tr: 'Dondurulan',
                    en: 'Frozen',
                    de: 'Gesperrt',
                  ),
                  value: frozen,
                ),
                _MiniBalance(
                  icon: Icons.account_balance_outlined,
                  label: _walletText(
                    context,
                    tr: 'Çekim bekliyor',
                    en: 'Withdrawal pending',
                    de: 'Auszahlung ausstehend',
                  ),
                  value: withdrawalPending,
                ),
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 92,
                ),
                itemBuilder: (context, index) => items[index],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MiniBalance extends StatelessWidget {
  const _MiniBalance({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalsSection extends StatelessWidget {
  const _WithdrawalsSection({
    required this.uid,
    required this.money,
    required this.date,
    required this.showMessage,
  });

  final String uid;
  final String Function(dynamic raw) money;
  final DateTime? Function(dynamic raw) date;
  final ValueChanged<String> showMessage;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: WalletService.watchWithdrawals(uid, limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _InlineLoadingCard(lines: 2);
        }
        if (snapshot.hasError) {
          return _InlineErrorCard(
            message: _walletText(
              context,
              tr: 'Çekim geçmişi şu anda görüntülenemiyor.',
              en: 'Withdrawal history is currently unavailable.',
              de: 'Der Auszahlungsverlauf ist derzeit nicht verfügbar.',
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) {
          return _EmptyCard(
            icon: Icons.account_balance_outlined,
            text: _walletText(
              context,
              tr: 'Henüz para çekme talebin yok.',
              en: 'You have no withdrawal requests yet.',
              de: 'Du hast noch keine Auszahlungsanfragen.',
            ),
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < docs.length; index++) ...<Widget>[
                _WithdrawalTile(
                  id: docs[index].id,
                  uid: uid,
                  data: docs[index].data(),
                  money: money,
                  date: date,
                  showMessage: showMessage,
                ),
                if (index != docs.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WithdrawalTile extends StatefulWidget {
  const _WithdrawalTile({
    required this.id,
    required this.uid,
    required this.data,
    required this.money,
    required this.date,
    required this.showMessage,
  });

  final String id;
  final String uid;
  final Map<String, dynamic> data;
  final String Function(dynamic raw) money;
  final DateTime? Function(dynamic raw) date;
  final ValueChanged<String> showMessage;

  @override
  State<_WithdrawalTile> createState() => _WithdrawalTileState();
}

class _WithdrawalTileState extends State<_WithdrawalTile> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String status = widget.data['status']?.toString().toLowerCase() ?? '';
    final bool pending = status == 'pending' || status == 'processing';
    final DateTime? createdAt = widget.date(widget.data['createdAt']);
    final String iban = widget.data['iban']?.toString() ?? '';
    final String maskedIban = iban.length >= 8
        ? '${iban.substring(0, 4)} •••• •••• ${iban.substring(iban.length - 4)}'
        : iban;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: pending ? colors.secondaryContainer : colors.surfaceContainerHighest,
        child: Icon(
          pending ? Icons.schedule_rounded : Icons.account_balance_outlined,
          color: pending ? colors.onSecondaryContainer : colors.onSurfaceVariant,
        ),
      ),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              widget.money(widget.data['amountKurus']),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          _StatusPill(
            text: _withdrawalStatus(context, status),
            icon: pending ? Icons.schedule_rounded : Icons.check_circle_outline,
            color: pending ? colors.secondary : colors.primary,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          <String>[
            if (maskedIban.isNotEmpty) maskedIban,
            if (createdAt != null)
              DateFormat('dd.MM.yyyy • HH:mm').format(createdAt),
          ].join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: pending
          ? IconButton(
        tooltip: _walletText(
          context,
          tr: 'Talebi iptal et',
          en: 'Cancel request',
          de: 'Anfrage stornieren',
        ),
        onPressed: _cancelling ? null : _cancel,
        icon: _cancelling
            ? const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.close_rounded),
      )
          : null,
    );
  }

  Future<void> _cancel() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _walletText(
            context,
            tr: 'Çekim talebini iptal et',
            en: 'Cancel withdrawal request',
            de: 'Auszahlungsanfrage stornieren',
          ),
        ),
        content: Text(
          _walletText(
            context,
            tr: 'Tutar yeniden kullanılabilir bakiyene aktarılacak.',
            en: 'The amount will return to your available balance.',
            de: 'Der Betrag wird deinem verfügbaren Guthaben wieder gutgeschrieben.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_walletText(context, tr: 'Vazgeç', en: 'Back', de: 'Zurück')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_walletText(context, tr: 'İptal et', en: 'Cancel', de: 'Stornieren')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final HttpsCallable callable =
      FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('cancelWithdrawal');

      await callable.call(<String, dynamic>{
        'withdrawalId': widget.id,
      });

      if (!mounted) return;

      widget.showMessage(
        _walletText(
          context,
          tr: 'Çekim talebi iptal edildi.',
          en: 'Withdrawal request cancelled.',
          de: 'Auszahlungsanfrage wurde storniert.',
        ),
      );
    } catch (error) {
      widget.showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _withdrawalStatus(BuildContext context, String status) {
    switch (status) {
      case 'pending':
      case 'processing':
        return _walletText(context, tr: 'Bekliyor', en: 'Pending', de: 'Ausstehend');
      case 'completed':
      case 'paid':
        return _walletText(context, tr: 'Tamamlandı', en: 'Completed', de: 'Abgeschlossen');
      case 'cancelled':
      case 'canceled':
        return _walletText(context, tr: 'İptal', en: 'Cancelled', de: 'Storniert');
      case 'failed':
      case 'rejected':
        return _walletText(context, tr: 'Başarısız', en: 'Failed', de: 'Fehlgeschlagen');
      default:
        return status.isEmpty ? '-' : status;
    }
  }
}

class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({
    required this.uid,
    required this.filtered,
    required this.money,
    required this.intValue,
    required this.date,
    required this.titleBuilder,
    required this.statusBuilder,
    required this.iconBuilder,
    required this.filterActive,
  });

  final String uid;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> Function(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) filtered;
  final String Function(dynamic raw) money;
  final int Function(dynamic raw) intValue;
  final DateTime? Function(dynamic raw) date;
  final String Function(Map<String, dynamic> data) titleBuilder;
  final String Function(Map<String, dynamic> data) statusBuilder;
  final IconData Function(Map<String, dynamic> data, int amount) iconBuilder;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: WalletService.watchTransactions(uid, limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _InlineLoadingCard(lines: 4);
        }
        if (snapshot.hasError) {
          return _InlineErrorCard(
            message: _walletText(
              context,
              tr: 'İşlem geçmişi şu anda görüntülenemiyor.',
              en: 'Transaction history is currently unavailable.',
              de: 'Der Transaktionsverlauf ist derzeit nicht verfügbar.',
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = filtered(
          snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        );
        if (docs.isEmpty) return _EmptyTransactions(filtered: filterActive);

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < docs.length; index++) ...<Widget>[
                _TransactionTile(
                  data: docs[index].data(),
                  money: money,
                  intValue: intValue,
                  date: date,
                  titleBuilder: titleBuilder,
                  statusBuilder: statusBuilder,
                  iconBuilder: iconBuilder,
                ),
                if (index != docs.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.data,
    required this.money,
    required this.intValue,
    required this.date,
    required this.titleBuilder,
    required this.statusBuilder,
    required this.iconBuilder,
  });

  final Map<String, dynamic> data;
  final String Function(dynamic raw) money;
  final int Function(dynamic raw) intValue;
  final DateTime? Function(dynamic raw) date;
  final String Function(Map<String, dynamic> data) titleBuilder;
  final String Function(Map<String, dynamic> data) statusBuilder;
  final IconData Function(Map<String, dynamic> data, int amount) iconBuilder;

  @override
  Widget build(BuildContext context) {
    final int amount = intValue(
      data['amountKurus'] ??
          data['amount'] ??
          data['netAmountKurus'] ??
          data['totalKurus'],
    );
    final DateTime? createdAt = date(
      data['createdAt'] ?? data['date'] ?? data['timestamp'],
    );
    final String status = statusBuilder(data);
    final String eventTitle = data['eventTitle']?.toString().trim() ?? '';
    final ColorScheme colors = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => _showDetails(context, amount, createdAt, status),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: amount < 0
            ? colors.errorContainer
            : colors.primaryContainer,
        child: Icon(
          iconBuilder(data, amount),
          color: amount < 0
              ? colors.onErrorContainer
              : colors.onPrimaryContainer,
        ),
      ),
      title: Text(
        titleBuilder(data),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        <String>[
          if (eventTitle.isNotEmpty) eventTitle,
          if (status.isNotEmpty) status,
          if (createdAt != null) DateFormat('dd.MM.yyyy • HH:mm').format(createdAt),
        ].join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 118),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '${amount > 0 ? '+' : ''}${money(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: amount < 0 ? colors.error : colors.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(
      BuildContext context,
      int amount,
      DateTime? createdAt,
      String status,
      ) {
    final String description = data['description']?.toString().trim() ?? '';
    final String eventTitle = data['eventTitle']?.toString().trim() ?? '';
    final String paymentId = data['paymentId']?.toString().trim() ?? '';
    final String withdrawalId = data['withdrawalId']?.toString().trim() ?? '';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _walletText(
                  context,
                  tr: 'İşlem detayı',
                  en: 'Transaction details',
                  de: 'Transaktionsdetails',
                ),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _DetailRow(
                label: _walletText(context, tr: 'İşlem', en: 'Transaction', de: 'Transaktion'),
                value: titleBuilder(data),
              ),
              _DetailRow(
                label: _walletText(context, tr: 'Tutar', en: 'Amount', de: 'Betrag'),
                value: '${amount > 0 ? '+' : ''}${money(amount)}',
              ),
              if (status.isNotEmpty)
                _DetailRow(
                  label: _walletText(context, tr: 'Durum', en: 'Status', de: 'Status'),
                  value: status,
                ),
              if (createdAt != null)
                _DetailRow(
                  label: _walletText(context, tr: 'Tarih', en: 'Date', de: 'Datum'),
                  value: DateFormat('dd.MM.yyyy • HH:mm').format(createdAt),
                ),
              if (eventTitle.isNotEmpty)
                _DetailRow(
                  label: _walletText(context, tr: 'Etkinlik', en: 'Event', de: 'Veranstaltung'),
                  value: eventTitle,
                ),
              if (description.isNotEmpty)
                _DetailRow(
                  label: _walletText(context, tr: 'Açıklama', en: 'Description', de: 'Beschreibung'),
                  value: description,
                ),
              if (paymentId.isNotEmpty)
                _DetailRow(
                  label: _walletText(context, tr: 'Ödeme kodu', en: 'Payment ID', de: 'Zahlungs-ID'),
                  value: paymentId,
                ),
              if (withdrawalId.isNotEmpty)
                _DetailRow(
                  label: _walletText(context, tr: 'Çekim kodu', en: 'Withdrawal ID', de: 'Auszahlungs-ID'),
                  value: withdrawalId,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EscrowInfoCard extends StatelessWidget {
  const _EscrowInfoCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield_outlined, color: colors.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _walletText(
                    context,
                    tr: 'Emanet ödeme koruması',
                    en: 'Escrow payment protection',
                    de: 'Treuhand-Zahlungsschutz',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  _walletText(
                    context,
                    tr: 'Etkinlik ödemeleri işlem tamamlanana kadar emanet hesapta tutulur. Koşullar tamamlandığında kazanç kullanılabilir bakiyeye geçer.',
                    en: 'Event payments are held in escrow until the transaction is completed. Earnings become available after the conditions are met.',
                    de: 'Veranstaltungszahlungen werden bis zum Abschluss treuhänderisch verwahrt. Nach Erfüllung der Bedingungen wird das Guthaben verfügbar.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletUsageCard extends StatelessWidget {
  const _WalletUsageCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _UsageTile(
            icon: Icons.credit_card_outlined,
            title: _walletText(context, tr: 'Çevrim içi ödeme', en: 'Online payment', de: 'Online-Zahlung'),
            subtitle: _walletText(
              context,
              tr: 'Etkinlik ödemelerinde cüzdan bakiyesi ve desteklenen ödeme yöntemleri kullanılabilir.',
              en: 'Wallet balance and supported payment methods can be used for event payments.',
              de: 'Für Veranstaltungszahlungen können Wallet-Guthaben und unterstützte Zahlungsmethoden verwendet werden.',
            ),
          ),
          const Divider(height: 1),
          _UsageTile(
            icon: Icons.replay_circle_filled_outlined,
            title: _walletText(context, tr: 'İadeyi bakiyeye al', en: 'Refund to balance', de: 'Rückerstattung als Guthaben'),
            subtitle: _walletText(
              context,
              tr: 'Uygun iptal iadeleri cüzdana yansıtılır ve sonraki etkinliklerde kullanılabilir.',
              en: 'Eligible cancellation refunds are added to the wallet and can be used for future events.',
              de: 'Berechtigte Stornierungsrückerstattungen werden dem Wallet gutgeschrieben und können später verwendet werden.',
            ),
          ),
          const Divider(height: 1),
          _UsageTile(
            icon: Icons.undo_outlined,
            title: _walletText(context, tr: 'Karta iade', en: 'Refund to card', de: 'Rückerstattung auf Karte'),
            subtitle: _walletText(
              context,
              tr: 'Uygun işlemlerde iade ödeme yapılan karta gönderilir. Süre bankaya göre değişebilir.',
              en: 'For eligible transactions, the refund is sent to the original payment card. Timing may vary by bank.',
              de: 'Bei berechtigten Transaktionen wird die Rückerstattung auf die ursprüngliche Karte gesendet. Die Dauer kann je nach Bank variieren.',
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return _EmptyCard(
      icon: Icons.receipt_long_outlined,
      text: filtered
          ? _walletText(
        context,
        tr: 'Bu kategoride işlem bulunamadı.',
        en: 'No transactions were found in this category.',
        de: 'In dieser Kategorie wurden keine Transaktionen gefunden.',
      )
          : _walletText(
        context,
        tr: 'Henüz bir işlem yok.',
        en: 'There are no transactions yet.',
        de: 'Es gibt noch keine Transaktionen.',
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _InlineLoadingCard extends StatelessWidget {
  const _InlineLoadingCard({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List<Widget>.generate(
            lines,
                (index) => Padding(
              padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(height: 13, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
                        const SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: 0.65,
                          child: Container(height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletLoadingState extends StatelessWidget {
  const _WalletLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        _LoadingBlock(height: 300),
        SizedBox(height: 16),
        _LoadingBlock(height: 132),
        SizedBox(height: 24),
        _InlineLoadingCard(lines: 4),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.cloud_off_outlined,
                size: 58,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _walletText(
                    context,
                    tr: 'Tekrar dene',
                    en: 'Retry',
                    de: 'Erneut versuchen',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
