import 'package:flutter/material.dart';

enum MarketPaymentSource {
  market,
  available,
}

extension MarketPaymentSourceValue on MarketPaymentSource {
  String get value {
    switch (this) {
      case MarketPaymentSource.market:
        return 'market';
      case MarketPaymentSource.available:
        return 'available';
    }
  }
}

Future<MarketPaymentSource?> showMarketPaymentSheet({
  required BuildContext context,
  required int priceKurus,
  required int marketBalanceKurus,
  required int availableBalanceKurus,
  required String title,
}) {
  return showModalBottomSheet<MarketPaymentSource>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _MarketPaymentSheet(
        title: title,
        priceKurus: priceKurus,
        marketBalanceKurus: marketBalanceKurus,
        availableBalanceKurus: availableBalanceKurus,
      );
    },
  );
}

class _MarketPaymentSheet extends StatefulWidget {
  const _MarketPaymentSheet({
    required this.title,
    required this.priceKurus,
    required this.marketBalanceKurus,
    required this.availableBalanceKurus,
  });

  final String title;
  final int priceKurus;
  final int marketBalanceKurus;
  final int availableBalanceKurus;

  @override
  State<_MarketPaymentSheet> createState() =>
      _MarketPaymentSheetState();
}

class _MarketPaymentSheetState
    extends State<_MarketPaymentSheet> {
  MarketPaymentSource? _selectedSource;

  String _money(int kurus) {
    final String whole = (kurus ~/ 100).toString();
    final String decimal =
    (kurus % 100).abs().toString().padLeft(2, '0');

    return '₺$whole,$decimal';
  }

  bool get _marketAvailable {
    return widget.marketBalanceKurus >= widget.priceKurus;
  }

  bool get _availableAvailable {
    return widget.availableBalanceKurus >= widget.priceKurus;
  }

  @override
  void initState() {
    super.initState();

    if (_marketAvailable && !_availableAvailable) {
      _selectedSource = MarketPaymentSource.market;
    } else if (!_marketAvailable && _availableAvailable) {
      _selectedSource = MarketPaymentSource.available;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Ödeme yöntemi',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _money(widget.priceKurus),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          _PaymentOptionCard(
            title: 'Market bakiyesi',
            subtitle: _money(widget.marketBalanceKurus),
            icon: Icons.shopping_bag_outlined,
            enabled: _marketAvailable,
            selected:
            _selectedSource == MarketPaymentSource.market,
            onTap: () {
              setState(() {
                _selectedSource = MarketPaymentSource.market;
              });
            },
          ),
          const SizedBox(height: 10),
          _PaymentOptionCard(
            title: 'Kullanılabilir bakiye',
            subtitle: _money(widget.availableBalanceKurus),
            icon: Icons.account_balance_wallet_outlined,
            enabled: _availableAvailable,
            selected:
            _selectedSource == MarketPaymentSource.available,
            onTap: () {
              setState(() {
                _selectedSource =
                    MarketPaymentSource.available;
              });
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _selectedSource == null
                ? null
                : () {
              Navigator.of(context).pop(_selectedSource);
            },
            icon: const Icon(Icons.lock_outline_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Ödemeyi Onayla'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yalnızca seçtiğin bakiyeden ödeme alınır.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? colors.primary
                    : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        enabled
                            ? subtitle
                            : '$subtitle · Yetersiz',
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
