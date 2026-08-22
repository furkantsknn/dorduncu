import 'package:flutter/material.dart';

import '../models/market_model.dart';

class MarketDetailScreen extends StatelessWidget {
  const MarketDetailScreen({
    super.key,
    required this.market,
  });

  final MarketModel market;

  @override
  Widget build(BuildContext context) {
    final String location = [
      market.address,
      market.district,
      market.city,
    ].where((value) => value.trim().isNotEmpty).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(market.name),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 82,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            market.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          if (market.category.isNotEmpty) ...[
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(
                Icons.category_outlined,
                size: 18,
              ),
              label: Text(market.category),
            ),
          ],
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Adres'),
            subtitle: Text(
              location.isEmpty ? 'Adres bilgisi bulunmuyor.' : location,
            ),
          ),
          if (market.hasLocation)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.map_outlined),
              title: const Text('Harita konumu'),
              subtitle: Text(
                '${market.latitude.toStringAsFixed(6)}, '
                    '${market.longitude.toStringAsFixed(6)}',
              ),
            ),
        ],
      ),
    );
  }
}