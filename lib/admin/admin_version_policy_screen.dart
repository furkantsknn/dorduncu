import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminVersionPolicyScreen extends StatefulWidget {
  const AdminVersionPolicyScreen({super.key});

  @override
  State<AdminVersionPolicyScreen> createState() =>
      _AdminVersionPolicyScreenState();
}

class _AdminVersionPolicyScreenState extends State<AdminVersionPolicyScreen> {
  String _platform = 'android';
  String _target = 'production';
  bool _active = false;
  bool _storeVerified = false;
  bool _busy = false;
  final _latestBuild = TextEditingController();
  final _minimumBuild = TextEditingController();
  final _latestVersion = TextEditingController();
  final _minimumVersion = TextEditingController();
  final _storeUrl = TextEditingController();
  final _tr = TextEditingController();
  final _en = TextEditingController();
  final _de = TextEditingController();
  final _rollbackRevision = TextEditingController();

  String get _policyId => '${_platform}_$_target';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _latestBuild,
      _minimumBuild,
      _latestVersion,
      _minimumVersion,
      _storeUrl,
      _tr,
      _en,
      _de,
      _rollbackRevision,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_version_policies')
          .doc(_policyId)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      _latestBuild.text = data['latestBuild']?.toString() ?? '';
      _minimumBuild.text = data['minimumBuild']?.toString() ?? '';
      _latestVersion.text = data['latestVersion']?.toString() ?? '';
      _minimumVersion.text = data['minimumVersion']?.toString() ?? '';
      _storeUrl.text = data['storeUrl']?.toString() ?? '';
      _tr.text = data['messageTr']?.toString() ?? '';
      _en.text = data['messageEn']?.toString() ?? '';
      _de.text = data['messageDe']?.toString() ?? '';
      _rollbackRevision.text = data['revisionId']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _active = data['active'] == true;
          _storeVerified = data['storeVersionAvailable'] == true;
        });
      }
    } catch (error) {
      _message('Politika yüklenemedi: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminManageVersionPolicy').call<void>(<String, dynamic>{
        'action': 'save',
        'platform': _platform,
        'target': _target,
        'active': _active,
        'storeVersionAvailable': _storeVerified,
        'latestBuild': int.tryParse(_latestBuild.text),
        'minimumBuild': int.tryParse(_minimumBuild.text),
        'latestVersion': _latestVersion.text,
        'minimumVersion': _minimumVersion.text,
        'storeUrl': _storeUrl.text,
        'messageTr': _tr.text,
        'messageEn': _en.text,
        'messageDe': _de.text,
      });
      _message(
        'Sürüm politikası kaydedildi. Minimum build yalnız mağaza doğrulamasıyla zorunlu olur.',
      );
      await _load();
    } on FirebaseFunctionsException catch (error) {
      _message(error.message ?? 'Politika kaydedilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rollback() async {
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('adminManageVersionPolicy').call<void>(<String, dynamic>{
        'action': 'rollback',
        'platform': _platform,
        'target': _target,
        'revisionId': _rollbackRevision.text.trim(),
      });
      _message('Politika önceki revizyona alındı.');
      await _load();
    } on FirebaseFunctionsException catch (error) {
      _message(error.message ?? 'Geri alma başarısız.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sürüm Politikaları')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _platform,
                  decoration: const InputDecoration(labelText: 'Platform'),
                  items: const [
                    DropdownMenuItem(value: 'android', child: Text('Android')),
                    DropdownMenuItem(value: 'ios', child: Text('iOS')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() => _platform = value!);
                          _load();
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _target,
                  decoration: const InputDecoration(labelText: 'Dağıtım'),
                  items: const [
                    DropdownMenuItem(value: 'test', child: Text('Test')),
                    DropdownMenuItem(
                      value: 'production',
                      child: Text('Production'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() => _target = value!);
                          _load();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Politika etkin'),
            value: _active,
            onChanged: _busy
                ? null
                : (value) => setState(() => _active = value),
          ),
          SwitchListTile(
            title: const Text('Mağaza sürümü erişilebilirliği doğrulandı'),
            subtitle: const Text(
              'Doğrulanmadan minimum build zorunlu kilit oluşturmaz.',
            ),
            value: _storeVerified,
            onChanged: _busy
                ? null
                : (value) => setState(() => _storeVerified = value),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _field(_latestBuild, 'Latest build', number: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_minimumBuild, 'Minimum build', number: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(child: _field(_latestVersion, 'Görünen latest sürüm')),
              const SizedBox(width: 12),
              Expanded(child: _field(_minimumVersion, 'Görünen minimum sürüm')),
            ],
          ),
          const SizedBox(height: 12),
          _field(_storeUrl, 'Play / App Store / TestFlight URL'),
          const SizedBox(height: 12),
          _field(_tr, 'Açıklama (TR)', lines: 3),
          const SizedBox(height: 12),
          _field(_en, 'Description (EN)', lines: 3),
          const SizedBox(height: 12),
          _field(_de, 'Beschreibung (DE)', lines: 3),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Politikayı kaydet'),
          ),
          const Divider(height: 40),
          _field(_rollbackRevision, 'Geri alınacak revizyon ID'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _rollback,
            icon: const Icon(Icons.history),
            label: const Text('Önceki politikaya geri al'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
    );
  }
}
