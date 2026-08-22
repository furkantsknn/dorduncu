import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bank_account_service.dart';

String _bankText(
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

class BankAccountsScreen extends StatelessWidget {
  const BankAccountsScreen({
    super.key,
    required this.uid,
    this.selectionMode = false,
  });

  final String uid;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _bankText(
            context,
            tr: 'Banka hesaplarım',
            en: 'My bank accounts',
            de: 'Meine Bankkonten',
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: BankAccountService.watchBankAccounts(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _BankAccountsError(
              message: _bankText(
                context,
                tr: 'Banka hesapları yüklenemedi.',
                en: 'Bank accounts could not be loaded.',
                de: 'Bankkonten konnten nicht geladen werden.',
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> accounts =
              snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (accounts.isEmpty) {
            return _EmptyBankAccounts(
              uid: uid,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final QueryDocumentSnapshot<Map<String, dynamic>> account =
              accounts[index];

              return _BankAccountCard(
                uid: uid,
                accountId: account.id,
                data: account.data(),
                selectionMode: selectionMode,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBankAccountForm(
          context: context,
          uid: uid,
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _bankText(
            context,
            tr: 'Hesap ekle',
            en: 'Add account',
            de: 'Konto hinzufügen',
          ),
        ),
      ),
    );
  }
}

class _BankAccountCard extends StatefulWidget {
  const _BankAccountCard({
    required this.uid,
    required this.accountId,
    required this.data,
    required this.selectionMode,
  });

  final String uid;
  final String accountId;
  final Map<String, dynamic> data;
  final bool selectionMode;

  @override
  State<_BankAccountCard> createState() => _BankAccountCardState();
}

class _BankAccountCardState extends State<_BankAccountCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final String bankName =
        widget.data['bankName']?.toString().trim() ?? '';

    final String iban =
        widget.data['iban']?.toString().trim() ?? '';

    final String accountHolderName =
        widget.data['accountHolderName']?.toString().trim() ?? '';

    final bool isDefault = widget.data['isDefault'] == true;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _loading
            ? null
            : widget.selectionMode
            ? () {
          Navigator.of(context).pop(<String, dynamic>{
            'id': widget.accountId,
            ...widget.data,
          });
        }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: const Icon(Icons.account_balance_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                bankName.isEmpty
                                    ? _bankText(
                                  context,
                                  tr: 'Banka hesabı',
                                  en: 'Bank account',
                                  de: 'Bankkonto',
                                )
                                    : bankName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _bankText(
                                    context,
                                    tr: 'Varsayılan',
                                    en: 'Default',
                                    de: 'Standard',
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                    color: colors.onPrimaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          accountHolderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          BankAccountService.maskIban(iban),
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!widget.selectionMode) ...<Widget>[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (!isDefault)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _loading ? null : _setDefault,
                          icon: const Icon(Icons.star_outline_rounded),
                          label: Text(
                            _bankText(
                              context,
                              tr: 'Varsayılan yap',
                              en: 'Make default',
                              de: 'Als Standard',
                            ),
                          ),
                        ),
                      ),
                    if (!isDefault) const SizedBox(width: 6),
                    IconButton(
                      tooltip: _bankText(
                        context,
                        tr: 'Düzenle',
                        en: 'Edit',
                        de: 'Bearbeiten',
                      ),
                      onPressed: _loading
                          ? null
                          : () => _showBankAccountForm(
                        context: context,
                        uid: widget.uid,
                        accountId: widget.accountId,
                        existingData: widget.data,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: _bankText(
                        context,
                        tr: 'Sil',
                        en: 'Delete',
                        de: 'Löschen',
                      ),
                      onPressed: _loading ? null : _delete,
                      icon: _loading
                          ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : Icon(
                        Icons.delete_outline_rounded,
                        color: colors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setDefault() async {
    setState(() => _loading = true);

    try {
      await BankAccountService.setDefaultBankAccount(
        uid: widget.uid,
        accountId: widget.accountId,
      );

      if (!mounted) return;

      _showMessage(
        _bankText(
          context,
          tr: 'Varsayılan banka hesabı güncellendi.',
          en: 'Default bank account updated.',
          de: 'Standardbankkonto wurde aktualisiert.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _delete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _bankText(
              context,
              tr: 'Banka hesabını sil',
              en: 'Delete bank account',
              de: 'Bankkonto löschen',
            ),
          ),
          content: Text(
            _bankText(
              context,
              tr: 'Bu banka hesabını silmek istediğine emin misin?',
              en: 'Are you sure you want to delete this bank account?',
              de: 'Möchtest du dieses Bankkonto wirklich löschen?',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                _bankText(
                  context,
                  tr: 'Vazgeç',
                  en: 'Back',
                  de: 'Zurück',
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                _bankText(
                  context,
                  tr: 'Sil',
                  en: 'Delete',
                  de: 'Löschen',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    try {
      await BankAccountService.deleteBankAccount(
        uid: widget.uid,
        accountId: widget.accountId,
      );

      if (!mounted) return;

      _showMessage(
        _bankText(
          context,
          tr: 'Banka hesabı silindi.',
          en: 'Bank account deleted.',
          de: 'Bankkonto wurde gelöscht.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }
}

class _EmptyBankAccounts extends StatelessWidget {
  const _EmptyBankAccounts({
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.account_balance_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              _bankText(
                context,
                tr: 'Kayıtlı banka hesabın yok',
                en: 'You have no saved bank accounts',
                de: 'Du hast keine gespeicherten Bankkonten',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _bankText(
                context,
                tr: 'Para çekme işlemlerinde kullanmak için banka hesabı ekleyebilirsin.',
                en: 'Add a bank account to use for withdrawal requests.',
                de: 'Füge ein Bankkonto für Auszahlungsanfragen hinzu.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _showBankAccountForm(
                context: context,
                uid: uid,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _bankText(
                  context,
                  tr: 'Banka hesabı ekle',
                  en: 'Add bank account',
                  de: 'Bankkonto hinzufügen',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankAccountsError extends StatelessWidget {
  const _BankAccountsError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 58,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showBankAccountForm({
  required BuildContext context,
  required String uid,
  String? accountId,
  Map<String, dynamic>? existingData,
}) async {
  final BuildContext parentContext = context;
  final bool editing = accountId != null && existingData != null;

  final TextEditingController bankNameController = TextEditingController(
    text: existingData?['bankName']?.toString() ?? '',
  );

  final TextEditingController accountHolderController =
  TextEditingController(
    text: existingData?['accountHolderName']?.toString() ?? '',
  );

  final TextEditingController ibanController = TextEditingController(
    text: BankAccountService.formatIban(
      existingData?['iban']?.toString() ?? '',
    ),
  );

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool makeDefault = existingData?['isDefault'] == true;
  bool loading = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContentContext, setSheetState) {
          Future<void> submit() async {
            if (!(formKey.currentState?.validate() ?? false)) return;

            setSheetState(() => loading = true);

            try {
              if (editing) {
                await BankAccountService.updateBankAccount(
                  uid: uid,
                  accountId: accountId,
                  bankName: bankNameController.text,
                  iban: ibanController.text,
                  accountHolderName: accountHolderController.text,
                  isDefault: makeDefault,
                );
              } else {
                await BankAccountService.addBankAccount(
                  uid: uid,
                  bankName: bankNameController.text,
                  iban: ibanController.text,
                  accountHolderName: accountHolderController.text,
                  makeDefault: makeDefault,
                );
              }

              if (!sheetContext.mounted) return;

              Navigator.of(sheetContext).pop();

              ScaffoldMessenger.of(parentContext)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      editing
                          ? _bankText(
                        sheetContentContext,
                        tr: 'Banka hesabı güncellendi.',
                        en: 'Bank account updated.',
                        de: 'Bankkonto wurde aktualisiert.',
                      )
                          : _bankText(
                        sheetContentContext,
                        tr: 'Banka hesabı eklendi.',
                        en: 'Bank account added.',
                        de: 'Bankkonto wurde hinzugefügt.',
                      ),
                    ),
                  ),
                );
            } catch (error) {
              if (!sheetContext.mounted) return;

              setSheetState(() => loading = false);

              ScaffoldMessenger.of(parentContext)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(error.toString()),
                  ),
                );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(sheetContentContext).bottom + 20,
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
                        editing
                            ? _bankText(
                          sheetContentContext,
                          tr: 'Banka hesabını düzenle',
                          en: 'Edit bank account',
                          de: 'Bankkonto bearbeiten',
                        )
                            : _bankText(
                          sheetContentContext,
                          tr: 'Banka hesabı ekle',
                          en: 'Add bank account',
                          de: 'Bankkonto hinzufügen',
                        ),
                        style:
                        Theme.of(sheetContentContext).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: bankNameController,
                        enabled: !loading,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: _bankText(
                            sheetContentContext,
                            tr: 'Banka adı',
                            en: 'Bank name',
                            de: 'Bankname',
                          ),
                          prefixIcon:
                          const Icon(Icons.account_balance_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().length < 2) {
                            return _bankText(
                              sheetContentContext,
                              tr: 'Geçerli bir banka adı gir.',
                              en: 'Enter a valid bank name.',
                              de: 'Gib einen gültigen Banknamen ein.',
                            );
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: accountHolderController,
                        enabled: !loading,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: _bankText(
                            sheetContentContext,
                            tr: 'Hesap sahibi',
                            en: 'Account holder',
                            de: 'Kontoinhaber',
                          ),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().length < 3) {
                            return _bankText(
                              sheetContentContext,
                              tr: 'Hesap sahibinin adını gir.',
                              en: 'Enter the account holder name.',
                              de: 'Gib den Namen des Kontoinhabers ein.',
                            );
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(sheetContentContext)
                              .colorScheme
                              .secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: Theme.of(sheetContentContext)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _bankText(
                                  sheetContentContext,
                                  tr: 'Banka hesabı, profilindeki ad ve soyad ile aynı kişiye ait olmalıdır. Farklı kişiye ait hesaplara ödeme gönderilmez.',
                                  en: 'The bank account must belong to the same person named in your profile. Payments are not sent to accounts owned by another person.',
                                  de: 'Das Bankkonto muss derselben Person gehören, deren Vor- und Nachname in deinem Profil steht. Zahlungen an Konten anderer Personen werden nicht ausgeführt.',
                                ),
                                style: Theme.of(sheetContentContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: Theme.of(sheetContentContext)
                                      .colorScheme
                                      .onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: ibanController,
                        enabled: !loading,
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.text,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(32),
                          _BankIbanInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'IBAN',
                          hintText: 'TR00 0000 0000 0000 0000 0000 00',
                          prefixIcon: Icon(Icons.credit_card_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final String normalized =
                          BankAccountService.normalizeIban(value ?? '');

                          if (!RegExp(r'^TR\d{24}$').hasMatch(normalized)) {
                            return _bankText(
                              sheetContentContext,
                              tr: 'Geçerli bir Türkiye IBAN numarası gir.',
                              en: 'Enter a valid Turkish IBAN.',
                              de: 'Gib eine gültige türkische IBAN ein.',
                            );
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: makeDefault,
                        onChanged: loading
                            ? null
                            : (value) {
                          setSheetState(() => makeDefault = value);
                        },
                        title: Text(
                          _bankText(
                            sheetContentContext,
                            tr: 'Varsayılan banka hesabı',
                            en: 'Default bank account',
                            de: 'Standardbankkonto',
                          ),
                        ),
                        subtitle: Text(
                          _bankText(
                            sheetContentContext,
                            tr: 'Para çekerken bu hesap öncelikli seçilir.',
                            en: 'This account will be selected first for withdrawals.',
                            de: 'Dieses Konto wird bei Auszahlungen zuerst ausgewählt.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: loading ? null : submit,
                        icon: loading
                            ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : Icon(
                          editing
                              ? Icons.save_outlined
                              : Icons.add_rounded,
                        ),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            editing
                                ? _bankText(
                              sheetContentContext,
                              tr: 'Değişiklikleri kaydet',
                              en: 'Save changes',
                              de: 'Änderungen speichern',
                            )
                                : _bankText(
                              sheetContentContext,
                              tr: 'Hesabı ekle',
                              en: 'Add account',
                              de: 'Konto hinzufügen',
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

  bankNameController.dispose();
  accountHolderController.dispose();
  ibanController.dispose();
}

class _BankIbanInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String normalized = newValue.text
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();

    if (normalized.length > 26) {
      normalized = normalized.substring(0, 26);
    }

    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < normalized.length; index++) {
      if (index > 0 && index % 4 == 0) {
        buffer.write(' ');
      }

      buffer.write(normalized[index]);
    }

    final String formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }
}