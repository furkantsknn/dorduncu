import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/digital_purchase_service.dart';

class _PreviewLine {
  const _PreviewLine({
    required this.productKey,
    required this.normalKurus,
    required this.discountedKurus,
    required this.eligibility,
    required this.periods,
    required this.renewalKurus,
  });

  final String productKey;
  final int normalKurus;
  final int discountedKurus;
  final String eligibility;
  final int? periods;
  final int? renewalKurus;
}

class AdminMarketCampaignsScreen extends StatefulWidget {
  const AdminMarketCampaignsScreen({super.key});

  @override
  State<AdminMarketCampaignsScreen> createState() =>
      _AdminMarketCampaignsScreenState();
}

class _AdminMarketCampaignsScreenState
    extends State<AdminMarketCampaignsScreen> {
  final TextEditingController _percent = TextEditingController(text: '20');
  final TextEditingController _periods = TextEditingController(text: '1');
  String _scope = 'all_market';
  String _campaignId = '';
  String _status = '';
  final Set<String> _selected = <String>{};
  List<_PreviewLine> _preview = const <_PreviewLine>[];
  bool _busy = false;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now().add(const Duration(days: 1));
    _end = _start.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _percent.dispose();
    _periods.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final DateTime current = start ? _start : _end;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) {
      return;
    }
    setState(() {
      final DateTime next = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = next;
      } else {
        _end = next;
      }
    });
  }

  Future<void> _save() async {
    if (!kMarketCampaignActionsEnabled) {
      setState(() => _status = 'Kampanya bu sürümde kapalı.');
      return;
    }
    if (_scope == 'selected' && _selected.isEmpty) {
      setState(() => _status = 'Seçili kapsam için en az bir ürün seç.');
      return;
    }
    if (!_end.isAfter(_start)) {
      setState(() => _status = 'Bitiş, başlangıçtan sonra olmalı.');
      return;
    }
    setState(() => _busy = true);
    try {
      final HttpsCallableResult<dynamic> result =
          await FirebaseFunctions.instanceFor(
            region: 'europe-west1',
          ).httpsCallable('adminSaveMarketCampaign').call(<String, dynamic>{
            if (_campaignId.isNotEmpty) 'campaignId': _campaignId,
            'scope': _scope,
            'percent': int.parse(_percent.text),
            'plusDiscountedPeriods': int.parse(_periods.text),
            'startsAt': _start.toUtc().toIso8601String(),
            'endsAt': _end.toUtc().toIso8601String(),
            'selectedProductKeys': _selected.toList(),
            'idempotencyKey': <String>[
              _campaignId,
              _scope,
              _percent.text,
              _start.toUtc().toIso8601String(),
              _end.toUtc().toIso8601String(),
              _periods.text,
              (_selected.toList()..sort()).join(','),
            ].join('|'),
          });
      final Map<Object?, Object?> data = result.data as Map<Object?, Object?>;
      setState(() {
        _campaignId = data['campaignId']?.toString() ?? _campaignId;
        _preview = _readPreview(data['preview']);
        _status =
            'Taslak $_campaignId kaydedildi. Yayınlama ayrıca onay ister.';
      });
    } on FirebaseFunctionsException catch (error) {
      setState(() => _status = error.message ?? 'Kampanya kaydedilemedi.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _call(String name, Map<String, dynamic> payload) async {
    if (!kMarketCampaignActionsEnabled) {
      setState(() => _status = 'Kampanya bu sürümde kapalı.');
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Google Play'),
          content: const Text(
            'Bu işlem kayıtlı kampanyayı Play tekliflerine yazar, '
            'durdurur veya tek ürünü yeniden dener. Canlı fiyat ancak '
            'onaydan sonra değişir.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Devam'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      final HttpsCallableResult<dynamic> result =
          await FirebaseFunctions.instanceFor(
            region: 'europe-west1',
          ).httpsCallable(name).call(payload);
      final Map<Object?, Object?> data = result.data as Map<Object?, Object?>;
      setState(() {
        _status =
            'Durum: ${data['status'] ?? ''}. '
            'Başarısız ürün: ${data['failed'] ?? 0}.';
      });
    } on FirebaseFunctionsException catch (error) {
      setState(() => _status = error.message ?? 'Kampanya işlemi başarısız.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market kampanyaları')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Normal fiyatlar: rozet ve rozet hediyesi 499 TRY, '
            'Plus ve Plus hediyesi 799 TRY. İndirim bu fiyattan hesaplanır. '
            'Mevcut aboneler kampanyaya taşınmaz. Plus hediye otomatik yenilenmez.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _scope,
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'all_market', child: Text('Tüm Market')),
              DropdownMenuItem(value: 'badges', child: Text('Yalnız rozetler')),
              DropdownMenuItem(value: 'plus', child: Text('Yalnız Plus')),
              DropdownMenuItem(
                value: 'selected',
                child: Text('Seçili ürünler'),
              ),
            ],
            onChanged: (value) => setState(() => _scope = value ?? _scope),
          ),
          if (_scope == 'selected')
            _SelectedProducts(
              selected: _selected,
              onChanged: (String key, bool checked) {
                setState(() {
                  if (checked) {
                    _selected.add(key);
                  } else {
                    _selected.remove(key);
                  }
                });
              },
            ),
          TextField(
            controller: _percent,
            decoration: const InputDecoration(labelText: 'Yüzde indirim'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _periods,
            decoration: const InputDecoration(
              labelText: 'Plus indirimli dönem sayısı',
              helperText:
                  'Sonrasında 799 TRY/ay yenilenir. Plus hediyesi ayrıdır.',
            ),
            keyboardType: TextInputType.number,
          ),
          ListTile(
            title: const Text('Başlangıç'),
            subtitle: Text(_start.toString()),
            onTap: () => _pickDate(start: true),
          ),
          ListTile(
            title: const Text('Bitiş'),
            subtitle: Text(_end.toString()),
            onTap: () => _pickDate(start: false),
          ),
          FilledButton(
            onPressed: !kMarketCampaignActionsEnabled || _busy ? null : _save,
            child: const Text('Taslak önizlemesini kaydet'),
          ),
          if (_campaignId.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: !kMarketCampaignActionsEnabled || _busy
                  ? null
                  : () => _call('adminPublishMarketCampaign', <String, dynamic>{
                      'campaignId': _campaignId,
                    }),
              child: const Text('Yayınla'),
            ),
            OutlinedButton(
              onPressed: !kMarketCampaignActionsEnabled || _busy
                  ? null
                  : () => _call('adminStopMarketCampaign', <String, dynamic>{
                      'campaignId': _campaignId,
                    }),
              child: const Text('Durdur'),
            ),
          ],
          if (_status.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(_status),
          ],
          ..._preview.map(_previewTile),
          const SizedBox(height: 16),
          const Text('Kayıtlı kampanyalar'),
          const _CampaignList(),
        ],
      ),
    );
  }

  Widget _previewTile(_PreviewLine line) {
    final String renewal = line.renewalKurus == null
        ? ''
        : ' Sonra ${_money(line.renewalKurus!)} / ${line.periods ?? 0} dönem.';
    return ListTile(
      title: Text(line.productKey),
      subtitle: Text(
        'Normal ${_money(line.normalKurus)} · '
        'İndirimli ${_money(line.discountedKurus)}.$renewal\n${line.eligibility}',
      ),
    );
  }
}

class _SelectedProducts extends StatelessWidget {
  const _SelectedProducts({required this.selected, required this.onChanged});

  final Set<String> selected;
  final void Function(String key, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('badge_products')
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (context, badges) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('plus_products')
              .where('active', isEqualTo: true)
              .snapshots(),
          builder: (context, plus) {
            final List<Widget> boxes = <Widget>[
              ..._boxes(badges.data?.docs ?? const [], true),
              ..._boxes(plus.data?.docs ?? const [], false),
            ];
            return Column(children: boxes);
          },
        );
      },
    );
  }

  List<Widget> _boxes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool badge,
  ) {
    return docs.expand((document) {
      final String title = document.data()['title']?.toString() ?? document.id;
      final List<(String, String)> keys = badge
          ? <(String, String)>[
              ('badge:${document.id}', 'Rozet $title'),
              ('badge_gift:${document.id}', 'Rozet hediyesi $title'),
            ]
          : <(String, String)>[
              ('plus:${document.id}', 'Plus $title'),
              ('plus_gift:${document.id}', 'Plus hediyesi $title'),
            ];
      return keys.map((entry) {
        return CheckboxListTile(
          value: selected.contains(entry.$1),
          title: Text(entry.$2),
          onChanged: (bool? checked) => onChanged(entry.$1, checked == true),
        );
      });
    }).toList();
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('market_campaigns')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Text('Kayıtlı kampanya yok.');
        }
        return Column(
          children: docs.map((document) {
            final Map<String, dynamic> data = document.data();
            final Object? products = data['products'];
            final List<Widget> retries = <Widget>[];
            if (products is Map) {
              products.forEach((Object? key, Object? value) {
                if (value is Map && value['syncStatus'] == 'failed') {
                  retries.add(
                    TextButton(
                      onPressed: kMarketCampaignActionsEnabled
                          ? () {
                              context
                                  .findAncestorStateOfType<
                                    _AdminMarketCampaignsScreenState
                                  >()
                                  ?._call(
                                    'adminRetryMarketCampaignProduct',
                                    <String, dynamic>{
                                      'campaignId': document.id,
                                      'productKey': key.toString(),
                                    },
                                  );
                            }
                          : null,
                      child: Text('Yeniden dene: $key'),
                    ),
                  );
                }
              });
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  title: Text('${data['status'] ?? ''} · ${document.id}'),
                  subtitle: Text(
                    'Kapsam ${data['scope'] ?? ''} · %${data['percent'] ?? ''}',
                  ),
                ),
                ...retries,
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

List<_PreviewLine> _readPreview(Object? raw) {
  if (raw is! List) {
    return const <_PreviewLine>[];
  }
  return raw.whereType<Map>().map((Map<dynamic, dynamic> item) {
    int number(Object? value) {
      return value is num ? value.toInt() : 0;
    }

    final Object? periods = item['plusDiscountedPeriods'];
    final Object? renewal = item['renewalPriceKurus'];
    return _PreviewLine(
      productKey: item['productKey']?.toString() ?? '',
      normalKurus: number(item['normalPriceKurus']),
      discountedKurus: number(item['discountedPriceKurus']),
      eligibility: item['eligibility']?.toString() ?? '',
      periods: periods is num ? periods.toInt() : null,
      renewalKurus: renewal is num ? renewal.toInt() : null,
    );
  }).toList();
}

String _money(int kurus) {
  return '${(kurus / 100).toStringAsFixed(2)} TRY';
}
