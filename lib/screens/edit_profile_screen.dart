import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_model.dart';
import '../utils/game_catalog.dart';
import 'avatar_picker_sheet.dart';

String _editProfileText(
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


String _editProfileCategoryName(
    BuildContext context,
    GameCategoryDefinition category,
    ) {
  final languageCode =
  Localizations.localeOf(context).languageCode.toLowerCase();

  switch (category.id) {
    case 'masa_oyunlari':
      return languageCode == 'en'
          ? 'Board Games'
          : languageCode == 'de'
          ? 'Brettspiele'
          : 'Masa Oyunları';
    case 'konsol_oyunlari':
      return languageCode == 'en'
          ? 'Console Games'
          : languageCode == 'de'
          ? 'Konsolenspiele'
          : 'Konsol Oyunları';
    case 'raket_sporlari':
      return languageCode == 'en'
          ? 'Racket Sports'
          : languageCode == 'de'
          ? 'Schlägersportarten'
          : 'Raket Sporları';
    case 'takim_sporlari':
      return languageCode == 'en'
          ? 'Team Sports'
          : languageCode == 'de'
          ? 'Mannschaftssportarten'
          : 'Takım Sporları';
    case 'premium_sporlar':
      return languageCode == 'en'
          ? 'Premium Sports'
          : languageCode == 'de'
          ? 'Premium-Sportarten'
          : 'Premium Sporlar';
    default:
      return category.name;
  }
}

String _editProfileGameName(
    BuildContext context,
    GameDefinition game,
    ) {
  final languageCode =
  Localizations.localeOf(context).languageCode.toLowerCase();

  if (languageCode == 'tr') {
    return game.name;
  }

  switch (game.id) {
    case 'tavla':
      return 'Backgammon';
    case 'satranc':
      return languageCode == 'de' ? 'Schach' : 'Chess';
    case 'bric':
      return 'Bridge';
    case 'tombala':
      return 'Bingo';
    case 'tenis':
      return 'Tennis';
    case 'masa_tenisi':
      return languageCode == 'de' ? 'Tischtennis' : 'Table Tennis';
    case 'futbol':
      return languageCode == 'de' ? 'Fußball' : 'Football';
    case 'basketbol':
      return 'Basketball';
    case 'voleybol':
      return 'Volleyball';
    case 'hentbol':
      return 'Handball';
    case 'yelken':
      return languageCode == 'de' ? 'Segeln' : 'Sailing';
    case 'kurek':
      return languageCode == 'de' ? 'Rudern' : 'Rowing';
    case 'binicilik':
      return languageCode == 'de' ? 'Reiten' : 'Horse Riding';
    case 'kayak':
      return languageCode == 'de' ? 'Skifahren' : 'Skiing';
    default:
      return game.name;
  }
}

String _editProfileGameDisplayName(
    BuildContext context,
    GameDefinition game,
    ) {
  return '${game.emoji} ${_editProfileGameName(context, game)}';
}

String _skillLevelText(BuildContext context, String value) {
  switch (value.trim().toLowerCase()) {
    case 'başlangıç':
    case 'baslangic':
      return _editProfileText(
        context,
        tr: 'Başlangıç',
        en: 'Beginner',
        de: 'Anfänger',
      );
    case 'orta':
      return _editProfileText(
        context,
        tr: 'Orta',
        en: 'Intermediate',
        de: 'Mittelstufe',
      );
    case 'iyi':
      return _editProfileText(
        context,
        tr: 'İyi',
        en: 'Advanced',
        de: 'Fortgeschritten',
      );
    case 'uzman':
    case 'profesyonel':
      return _editProfileText(
        context,
        tr: value,
        en: 'Expert',
        de: 'Experte',
      );
    default:
      return value;
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialData,
  });

  final Map<String, dynamic> initialData;

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController aboutController;

  final Map<String, UserGameSkill> selectedSkills =
  <String, UserGameSkill>{};

  String photoUrl = '';
  String avatarUrl = '';
  XFile? pickedPhoto;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    aboutController = TextEditingController(
      text: widget.initialData['hakkimda']?.toString() ?? '',
    );

    photoUrl =
        widget.initialData['profilFotografi']?.toString() ?? '';
    avatarUrl =
        widget.initialData['avatarUrl']?.toString() ?? '';

    final userModel = UserModel.fromMap(widget.initialData);
    selectedSkills.addAll(userModel.gameSkills);
  }

  @override
  void dispose() {
    aboutController.dispose();
    super.dispose();
  }

  ImageProvider? get imageProvider {
    if (pickedPhoto != null) {
      return FileImage(File(pickedPhoto!.path));
    }

    if (photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }

    if (avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    }

    return null;
  }

  Future<void> _pickGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1200,
    );

    if (file != null && mounted) {
      setState(() {
        pickedPhoto = file;
        avatarUrl = '';
      });
    }
  }

  Future<void> _pickCamera() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1200,
    );

    if (file != null && mounted) {
      setState(() {
        pickedPhoto = file;
        avatarUrl = '';
      });
    }
  }

  Future<void> _pickAvatar() async {
    final selected = await showAvatarPicker(
      context,
      selected: avatarUrl,
    );

    if (selected != null && mounted) {
      setState(() {
        avatarUrl = selected;
        pickedPhoto = null;
        photoUrl = '';
      });
    }
  }

  Future<void> _photoMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading:
                const Icon(Icons.photo_library_outlined),
                title: Text(
                  _editProfileText(
                    context,
                    tr: 'Galeriden fotoğraf seç',
                    en: 'Choose photo from gallery',
                    de: 'Foto aus Galerie auswählen',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickGallery();
                },
              ),
              ListTile(
                leading:
                const Icon(Icons.camera_alt_outlined),
                title: Text(
                  _editProfileText(
                    context,
                    tr: 'Kamerayla çek',
                    en: 'Take a photo',
                    de: 'Foto aufnehmen',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.face_6_outlined),
                title: Text(
                  _editProfileText(
                    context,
                    tr: '3D avatar seç',
                    en: 'Choose a 3D avatar',
                    de: '3D-Avatar auswählen',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: Text(
                  _editProfileText(
                    context,
                    tr: 'Görseli kaldır',
                    en: 'Remove image',
                    de: 'Bild entfernen',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    pickedPhoto = null;
                    photoUrl = '';
                    avatarUrl = '';
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleGame(GameDefinition game, bool selected) {
    setState(() {
      if (selected) {
        final category =
        GameCatalog.categoryById(game.categoryId);
        final defaultLevel = GameCatalog.skillLevels.first;

        selectedSkills[game.id] = UserGameSkill(
          gameId: game.id,
          gameName: game.name,
          categoryId: game.categoryId,
          categoryName: category?.name ?? '',
          level: defaultLevel.value,
          levelLabel: defaultLevel.label,
        );
      } else {
        selectedSkills.remove(game.id);
      }
    });
  }

  void _setSkillLevel(
      GameDefinition game,
      SkillLevelDefinition level,
      ) {
    final currentSkill = selectedSkills[game.id];
    if (currentSkill == null) {
      return;
    }

    setState(() {
      selectedSkills[game.id] = currentSkill.copyWith(
        level: level.value,
        levelLabel: level.label,
      );
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || saving) {
      return;
    }

    if (selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editProfileText(
              context,
              tr: 'Profilini kullanabilmek için en az bir oyun veya spor seçmelisin.',
              en: 'Select at least one game or sport to use your profile.',
              de: 'Wähle mindestens ein Spiel oder eine Sportart aus, um dein Profil zu nutzen.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      var uploadedUrl = photoUrl;

      if (pickedPhoto != null) {
        final ref = FirebaseStorage.instance.ref(
          'profile_photos/${user.uid}/'
              'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        await ref.putFile(File(pickedPhoto!.path));
        uploadedUrl = await ref.getDownloadURL();
      }

      final sortedSkills = selectedSkills.values.toList()
        ..sort(
              (a, b) => a.gameName.compareTo(b.gameName),
        );

      final gameNames = sortedSkills
          .map((skill) => skill.gameName)
          .toSet()
          .toList();

      final gameIds = sortedSkills
          .map((skill) => skill.gameId)
          .toSet()
          .toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        <String, dynamic>{
          'profilFotografi': uploadedUrl,
          'avatarUrl':
          uploadedUrl.isNotEmpty ? '' : avatarUrl,
          'oyunlar': gameNames,
          'gameIds': gameIds,
          'gameSkills': <String, dynamic>{
            for (final skill in sortedSkills)
              skill.gameId: skill.toMap(),
          },
          'hakkimda': aboutController.text.trim(),

          'guncellemeTarihi':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_editProfileText(
              context,
              tr: 'Kaydedilemedi',
              en: 'Could not save',
              de: 'Speichern fehlgeschlagen',
            )} (${error.code}): ${error.message ?? ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_editProfileText(
              context,
              tr: 'Kaydedilemedi',
              en: 'Could not save',
              de: 'Speichern fehlgeschlagen',
            )}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editProfileText(
            context,
            tr: 'Profili düzenle',
            en: 'Edit profile',
            de: 'Profil bearbeiten',
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : Text(
              _editProfileText(
                context,
                tr: 'Kaydet',
                en: 'Save',
                de: 'Speichern',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          12,
          18,
          32,
        ),
        children: [
          _buildProfilePhoto(),
          const SizedBox(height: 28),
          _buildGameSelection(),
          const SizedBox(height: 26),
          TextField(
            controller: aboutController,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: _editProfileText(
                context,
                tr: 'Hakkımda',
                en: 'About me',
                de: 'Über mich',
              ),
              hintText: _editProfileText(
                context,
                tr: 'Kendinden ve oyun tarzından kısaca bahset.',
                en: 'Briefly describe yourself and your playing style.',
                de: 'Beschreibe dich und deinen Spielstil kurz.',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                saving
                    ? _editProfileText(
                  context,
                  tr: 'Kaydediliyor...',
                  en: 'Saving...',
                  de: 'Wird gespeichert...',
                )
                    : _editProfileText(
                  context,
                  tr: 'Değişiklikleri kaydet',
                  en: 'Save changes',
                  de: 'Änderungen speichern',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 62,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? const Icon(
                  Icons.person,
                  size: 64,
                )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  onPressed: _photoMenu,
                  icon: const Icon(Icons.edit),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _editProfileText(
            context,
            tr: 'Fotoğraf, kamera veya 3D avatar kullanabilirsin.',
            en: 'You can use a photo, camera or 3D avatar.',
            de: 'Du kannst ein Foto, die Kamera oder einen 3D-Avatar verwenden.',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGameSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _editProfileText(
            context,
            tr: 'Oyunlarım ve sporlarım',
            en: 'My games and sports',
            de: 'Meine Spiele und Sportarten',
          ),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          _editProfileText(
            context,
            tr: 'Yalnızca profiline eklediğin oyunların etkinliklerine başvurabilirsin. Her branş için seviyeni seç.',
            en: 'You can only apply to events for games added to your profile. Choose your level for each discipline.',
            de: 'Du kannst dich nur für Veranstaltungen der Spiele bewerben, die deinem Profil hinzugefügt wurden. Wähle für jede Disziplin dein Niveau.',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _editProfileText(
            context,
            tr: '${selectedSkills.length} branş seçildi',
            en: '${selectedSkills.length} disciplines selected',
            de: '${selectedSkills.length} Disziplinen ausgewählt',
          ),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
        ),
        const SizedBox(height: 14),
        for (final category in GameCatalog.categories)
          _buildCategoryCard(category),
      ],
    );
  }

  Widget _buildCategoryCard(
      GameCategoryDefinition category,
      ) {
    final selectedInCategory = category.games
        .where(
          (game) => selectedSkills.containsKey(game.id),
    )
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: selectedInCategory > 0,
        leading: Text(
          category.emoji,
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(
          _editProfileCategoryName(context, category),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          selectedInCategory == 0
              ? _editProfileText(
            context,
            tr: '${category.games.length} branş',
            en: '${category.games.length} disciplines',
            de: '${category.games.length} Disziplinen',
          )
              : _editProfileText(
            context,
            tr: '$selectedInCategory branş seçildi',
            en: '$selectedInCategory disciplines selected',
            de: '$selectedInCategory Disziplinen ausgewählt',
          ),
        ),
        childrenPadding:
        const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          for (final game in category.games)
            _buildGameItem(game),
        ],
      ),
    );
  }

  Widget _buildGameItem(GameDefinition game) {
    final skill = selectedSkills[game.id];
    final selected = skill != null;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity:
            ListTileControlAffinity.leading,
            value: selected,
            onChanged: (value) {
              _toggleGame(game, value ?? false);
            },
            title: Text(
              _editProfileGameDisplayName(context, game),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              selected
                  ? '${_skillLevelText(context, skill.levelLabel)} · %${skill.level}'
                  : _editProfileText(
                context,
                tr: 'Profiline eklemek için seç',
                en: 'Select to add to your profile',
                de: 'Auswählen, um es deinem Profil hinzuzufügen',
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: skill.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                for (final level
                in GameCatalog.skillLevels)
                  ButtonSegment<int>(
                    value: level.value,
                    label: Text(
                      '%${level.value}\n${_skillLevelText(context, level.label)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              selected: <int>{skill.level},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }

                final selectedLevel =
                GameCatalog.skillLevelForValue(
                  selection.first,
                );

                _setSkillLevel(
                  game,
                  selectedLevel,
                );
              },
              showSelectedIcon: false,
            ),
          ],
        ],
      ),
    );
  }
}