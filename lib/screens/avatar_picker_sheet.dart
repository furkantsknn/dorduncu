import 'package:flutter/material.dart';

const List<String> dorduncuAvatars = [
  'https://api.dicebear.com/9.x/adventurer/png?seed=Atlas&backgroundColor=ffd5dc',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Luna&backgroundColor=c0aede',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Arda&backgroundColor=b6e3f4',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Mira&backgroundColor=ffdfbf',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Deniz&backgroundColor=d1d4f9',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Ege&backgroundColor=c0aede',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Ada&backgroundColor=ffd5dc',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Bora&backgroundColor=b6e3f4',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Selin&backgroundColor=ffdfbf',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Can&backgroundColor=d1d4f9',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Elif&backgroundColor=c0aede',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Mert&backgroundColor=b6e3f4',
];

Future<String?> showAvatarPicker(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_avatarPickerText(context, tr: '3D avatarını seç', en: 'Choose your 3D avatar', de: 'Wähle deinen 3D-Avatar'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(_avatarPickerText(context, tr: 'Daha sonra profilinden değiştirebilirsin.', en: 'You can change it later from your profile.', de: 'Du kannst ihn später in deinem Profil ändern.')),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemCount: dorduncuAvatars.length,
              itemBuilder: (context, index) {
                final url = dorduncuAvatars[index];
                final active = url == selected;
                return InkWell(
                  onTap: () => Navigator.pop(context, url),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 4)),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(backgroundImage: NetworkImage(url), backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

String _avatarPickerText(
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

