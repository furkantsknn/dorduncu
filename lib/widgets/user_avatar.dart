import 'package:flutter/material.dart';

String resolveUserImageUrl(Map<String, dynamic> data) {
  final candidates = <dynamic>[
    data['profilFotografi'],
    data['avatarUrl'],
    data['profilFotoUrl'],
    data['profilePhoto'],
    data['profilePhotoUrl'],
    data['photoUrl'],
  ];

  for (final candidate in candidates) {
    final value = candidate?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }

  return '';
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.imageUrl = '',
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
  });

  final String displayName;
  final String imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;

  String get _initial {
    final value = displayName.trim();
    if (value.isEmpty) {
      return '?';
    }
    return value.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = imageUrl.trim();
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor:
      backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      foregroundColor:
      foregroundColor ?? Theme.of(context).colorScheme.onPrimaryContainer,
      backgroundImage:
      resolvedImageUrl.isNotEmpty ? NetworkImage(resolvedImageUrl) : null,
      child: resolvedImageUrl.isEmpty
          ? Text(
        _initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w800,
        ),
      )
          : null,
    );

    if (onTap == null) {
      return avatar;
    }

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
