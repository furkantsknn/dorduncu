import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

String _locText(
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


class AdminWalletAdjustmentScreen extends StatefulWidget {
  const AdminWalletAdjustmentScreen({super.key, required this.userId});

  final String userId;

  @override
  State<AdminWalletAdjustmentScreen> createState() =>
      _AdminWalletAdjustmentScreenState();
}

class _AdminWalletAdjustmentScreenState
    extends State<AdminWalletAdjustmentScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String _selectedOperation = 'balance_add';
  String _selectedBalanceType = 'withdrawable';
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isBalanceOperation {
    return _selectedOperation == 'balance_add' ||
        _selectedOperation == 'balance_remove';
  }

  String get _selectedBalanceLabel {
    return _selectedBalanceType == 'market'
        ? 'Market Bakiyesi'
        : 'Çekilebilir Bakiye';
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final String amountText = _amountController.text.trim().replaceAll(
      ',',
      '.',
    );

    final double? amount = double.tryParse(amountText);
    final String reason = _reasonController.text.trim();

    if (amount == null || amount <= 0) {
      _showMessage('Geçerli bir tutar gir.');
      return;
    }

    if (reason.length < 3) {
      _showMessage('İşlem açıklamasını yaz.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('İşlemi Onayla'),
          content: Text(
            '${_operationTitle(_selectedOperation)}\n\n'
            '${_isBalanceOperation ? amount.toStringAsFixed(2) : amount.toStringAsFixed(0)} '
            '${_isBalanceOperation ? 'TL' : 'puan'}\n'
            '${_isBalanceOperation ? 'Bakiye türü: $_selectedBalanceLabel\n' : ''}\n'
            'Açıklama: $reason',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(_locText(context, tr: 'Vazgeç', en: 'Cancel', de: 'Abbrechen')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Onayla'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminAdjustWallet');

      await callable.call(<String, dynamic>{
        'userId': widget.userId,
        'operation': _selectedOperation,
        'balanceType': _selectedBalanceType,
        'amount': amount,
        'reason': reason,
      });

      if (!mounted) {
        return;
      }

      _amountController.clear();
      _reasonController.clear();

      _showMessage('İşlem başarıyla tamamlandı.');
    } catch (error) {
      _showMessage('İşlem tamamlanamadı: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
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
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _operationTitle(String value) {
    switch (value) {
      case 'balance_add':
        return 'Bakiye Ekle';
      case 'balance_remove':
        return 'Bakiye Düş';
      case 'point_add':
        return 'Puan Ekle';
      case 'point_remove':
        return 'Puan Düş';
      default:
        return 'İşlem';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bakiye ve Puan İşlemi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'İşlem Türü',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOperation,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'balance_add',
                        child: Text('Bakiye Ekle'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'balance_remove',
                        child: Text('Bakiye Düş'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'point_add',
                        child: Text('Puan Ekle'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'point_remove',
                        child: Text('Puan Düş'),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (String? value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _selectedOperation = value;
                              _amountController.clear();
                            });
                          },
                  ),
                  if (_isBalanceOperation) ...<Widget>[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBalanceType,
                      decoration: const InputDecoration(
                        labelText: 'Bakiye Türü',
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'market',
                          child: Text('Sadece Market Bakiyesi'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'withdrawable',
                          child: Text('Çekilebilir Bakiye'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (String? value) {
                              if (value == null) return;

                              setState(() {
                                _selectedBalanceType = value;
                              });
                            },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _isBalanceOperation ? 'Tutar' : 'Puan',
                      suffixText: _isBalanceOperation ? 'TL' : 'puan',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: _locText(context, tr: 'İşlem açıklaması', en: 'Action description', de: 'Aktionsbeschreibung'),
                      hintText:
                          'Örnek: Kampanya ödülü, manuel düzeltme veya iade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          _saving
                              ? 'Kaydediliyor...'
                              : _operationTitle(_selectedOperation),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
