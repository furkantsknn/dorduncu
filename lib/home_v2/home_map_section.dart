import 'package:flutter/material.dart';

class MapSection extends StatelessWidget {
  const MapSection({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.map,
    super.key,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget map;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: Color(0xffFF9800),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        map,
      ],
    );
  }
}
