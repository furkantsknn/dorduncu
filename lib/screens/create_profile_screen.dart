import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'home_screen.dart';
import 'avatar_picker_sheet.dart';
import '../utils/game_catalog.dart';
import '../utils/turkey_location_service.dart';
import '../services/language_controller.dart';
import '../services/session_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState
    extends State<CreateProfileScreen> {
  _CreateProfileText get text =>
      _CreateProfileText(LanguageController.language.value);

  final PageController pageController = PageController();

  final TextEditingController nameController =
  TextEditingController();

  final TextEditingController surnameController =
  TextEditingController();

  final TextEditingController cityController =
  TextEditingController();

  final TextEditingController districtController =
  TextEditingController();

  final TextEditingController aboutController =
  TextEditingController();

  final ImagePicker imagePicker = ImagePicker();

  int currentStep = 0;

  bool loading = false;
  bool verificationSkipped = false;
  bool verificationUploaded = false;

  DateTime? birthDate;
  String? selectedGender;

  XFile? profilePhoto;
  String selectedAvatarUrl = '';
  XFile? selfiePhoto;

  PlatformFile? identityFront;
  PlatformFile? identityBack;
  PlatformFile? criminalRecord;

  String? identityFrontUrl;
  String? identityBackUrl;
  String? criminalRecordUrl;
  String? selfieUrl;

  final Map<String, int> selectedGameLevels = <String, int>{};

  final List<String> genders = [
    "Kadın",
    "Erkek",
    "Belirtmek istemiyorum",
  ];

  List<String> get selectedGameNames => selectedGameLevels.keys
      .map((gameId) => GameCatalog.gameById(gameId)?.name ?? '')
      .where((name) => name.isNotEmpty)
      .toList();

  Map<String, dynamic> get selectedGameSkillsMap {
    final result = <String, dynamic>{};

    for (final entry in selectedGameLevels.entries) {
      final game = GameCatalog.gameById(entry.key);
      if (game == null) {
        continue;
      }

      final skillLevel =
      GameCatalog.skillLevelForValue(entry.value);

      result[entry.key] = <String, dynamic>{
        'gameId': game.id,
        'gameName': game.name,
        'categoryId': game.categoryId,
        'categoryName':
        GameCatalog.categoryById(game.categoryId)?.name ?? '',
        'level': skillLevel.value,
        'levelLabel': skillLevel.label,
      };
    }

    return result;
  }


  bool get verificationFilesComplete {
    return identityFront != null &&
        identityBack != null &&
        criminalRecord != null &&
        selfiePhoto != null;
  }

  int calculateAge(DateTime date) {
    final DateTime today = DateTime.now();

    int age = today.year - date.year;

    final bool birthdayPassed =
        today.month > date.month ||
            (today.month == date.month &&
                today.day >= date.day);

    if (!birthdayPassed) {
      age--;
    }

    return age;
  }

  Future<void> selectBirthDate() async {
    final DateTime today = DateTime.now();

    final DateTime latestAllowedDate = DateTime(
      today.year - 18,
      today.month,
      today.day,
    );

    final DateTime initialDate =
        birthDate ?? DateTime(latestAllowedDate.year - 7, 1, 1);

    final DateTime? selectedDate = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        DateTime tempDate = initialDate;

        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setModalState,
              ) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.only(top: 60),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                decoration: const BoxDecoration(
                  color: Color(0xff171A20),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.cake_outlined,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            text.selectBirthDate,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.orange,
                          onPrimary: Colors.black,
                          surface: Color(0xff171A20),
                          onSurface: Colors.white,
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: tempDate,
                        firstDate: DateTime(1900, 1, 1),
                        lastDate: latestAllowedDate,
                        onDateChanged: (DateTime value) {
                          setModalState(() {
                            tempDate = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(
                                color: Colors.white24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(text.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                sheetContext,
                                tempDate,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              text.select,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedDate == null) {
      return;
    }

    if (calculateAge(selectedDate) < 18) {
      showMessage(
        text.ageRestriction,
      );
      return;
    }

    setState(() {
      birthDate = selectedDate;
    });
  }

  Future<void> selectProfilePhoto() async {
    try {
      final XFile? selectedImage =
      await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (selectedImage == null) {
        return;
      }

      setState(() {
        profilePhoto = selectedImage;
      });
    } catch (_) {
      showMessage(text.profilePhotoCouldNotBeSelected);
    }
  }

  Future<void> selectAvatar() async {
    final String? selected = await showAvatarPicker(
      context,
      selected: selectedAvatarUrl,
    );
    if (selected == null || !mounted) return;
    setState(() {
      selectedAvatarUrl = selected;
      profilePhoto = null;
    });
  }

  Future<void> selectSelfie() async {
    try {
      final XFile? selectedImage =
      await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (selectedImage == null) {
        return;
      }

      setState(() {
        selfiePhoto = selectedImage;
        verificationUploaded = false;
      });
    } catch (_) {
      showMessage(text.selfieCouldNotBeTaken);
    }
  }

  Future<PlatformFile?> selectDocument() async {
    try {
      final FilePickerResult? result =
      await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          "pdf",
          "jpg",
          "jpeg",
          "png",
        ],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final PlatformFile selectedFile =
          result.files.first;

      if (selectedFile.path == null) {
        showMessage(text.selectedFileCouldNotBeAccessed);
        return null;
      }

      const int maximumFileSize =
          10 * 1024 * 1024;

      if (selectedFile.size > maximumFileSize) {
        showMessage(
          text.maximumFileSize,
        );
        return null;
      }

      return selectedFile;
    } catch (_) {
      showMessage(
        text.documentSelectionError,
      );
      return null;
    }
  }

  Future<PlatformFile?> selectIdentityImage() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xff171A20),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        builder: (BuildContext sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.orange,
                    ),
                    title: const Text(
                      'Kameradan çek',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                        ImageSource.camera,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.orange,
                    ),
                    title: const Text(
                      'Galeriden seç',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                        ImageSource.gallery,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (source == null) {
        return null;
      }

      final XFile? image = await imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
      );

      if (image == null) {
        return null;
      }

      final File file = File(image.path);
      final int size = await file.length();

      return PlatformFile(
        name: image.name,
        path: image.path,
        size: size,
      );
    } catch (_) {
      showMessage(text.documentSelectionError);
      return null;
    }
  }
  Future<void> selectIdentityFront() async {
    final PlatformFile? selectedFile =
    await selectIdentityImage();

    if (selectedFile == null) {
      return;
    }

    setState(() {
      identityFront = selectedFile;
      verificationUploaded = false;
    });
  }

  Future<void> selectIdentityBack() async {
    final PlatformFile? selectedFile =
    await selectIdentityImage();

    if (selectedFile == null) {
      return;
    }

    setState(() {
      identityBack = selectedFile;
      verificationUploaded = false;
    });
  }

  Future<void> selectCriminalRecord() async {
    final PlatformFile? selectedFile =
    await selectDocument();

    if (selectedFile == null) {
      return;
    }

    setState(() {
      criminalRecord = selectedFile;
      verificationUploaded = false;
    });
  }

  bool validateProfileStep() {
    final String name =
    nameController.text.trim();

    final String surname =
    surnameController.text.trim();

    final String city =
    cityController.text.trim();

    final String district =
    districtController.text.trim();

    if (name.isEmpty) {
      showMessage(text.enterName);
      return false;
    }

    if (surname.isEmpty) {
      showMessage(text.enterSurname);
      return false;
    }

    if (birthDate == null) {
      showMessage(text.selectBirthDateValidation);
      return false;
    }

    if (calculateAge(birthDate!) < 18) {
      showMessage(
        text.ageRestriction,
      );
      return false;
    }

    if (selectedGender == null) {
      showMessage(text.selectGender);
      return false;
    }

    if (city.isEmpty) {
      showMessage(text.enterCity);
      return false;
    }

    if (district.isEmpty) {
      showMessage(text.enterDistrict);
      return false;
    }

    return true;
  }

  void goToVerificationStep() {
    FocusScope.of(context).unfocus();

    if (!validateProfileStep()) {
      return;
    }

    pageController.nextPage(
      duration: const Duration(
        milliseconds: 300,
      ),
      curve: Curves.easeInOut,
    );
  }

  Future<String> uploadFile({
    required File file,
    required String storagePath,
  }) async {
    final Reference reference =
    FirebaseStorage.instance
        .ref()
        .child(storagePath);

    final UploadTask uploadTask =
    reference.putFile(file);

    final TaskSnapshot snapshot =
    await uploadTask;

    return snapshot.ref.getDownloadURL();
  }

  Future<void>
  uploadVerificationDocuments() async {
    if (!verificationFilesComplete) {
      showMessage(
        text.addAllVerificationFiles,
      );
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        text.userSessionNotFound,
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final String timestamp =
      DateTime.now()
          .millisecondsSinceEpoch
          .toString();

      final String basePath =
          "verification_documents/${user.uid}";

      identityFrontUrl = await uploadFile(
        file: File(identityFront!.path!),
        storagePath:
        "$basePath/identity_front_$timestamp.${getFileExtension(identityFront!.name)}",
      );

      identityBackUrl = await uploadFile(
        file: File(identityBack!.path!),
        storagePath:
        "$basePath/identity_back_$timestamp.${getFileExtension(identityBack!.name)}",
      );

      criminalRecordUrl = await uploadFile(
        file: File(criminalRecord!.path!),
        storagePath:
        "$basePath/criminal_record_$timestamp.${getFileExtension(criminalRecord!.name)}",
      );

      selfieUrl = await uploadFile(
        file: File(selfiePhoto!.path),
        storagePath:
        "$basePath/selfie_$timestamp.jpg",
      );

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
        verificationUploaded = true;
        verificationSkipped = false;
      });

      pageController.nextPage(
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeInOut,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      showMessage(
        text.documentUploadError(error),
      );
    }
  }

  void skipVerification() {
    setState(() {
      verificationSkipped = true;
      verificationUploaded = false;
    });

    pageController.nextPage(
      duration: const Duration(
        milliseconds: 300,
      ),
      curve: Curves.easeInOut,
    );
  }

  String getFileExtension(String fileName) {
    final List<String> parts =
    fileName.split(".");

    if (parts.length < 2) {
      return "file";
    }

    return parts.last.toLowerCase();
  }

  Future<void> createProfile() async {
    if (selectedGameLevels.isEmpty) {
      showMessage(
        text.selectAtLeastOneGame,
      );
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        text.userSessionNotFound,
      );
      return;
    }

    if (birthDate == null) {
      showMessage(
        text.birthDateNotFound,
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      String profilePhotoUrl = "";

      if (profilePhoto != null) {
        final String timestamp =
        DateTime.now()
            .millisecondsSinceEpoch
            .toString();

        profilePhotoUrl = await uploadFile(
          file: File(profilePhoto!.path),
          storagePath:
          "profile_photos/${user.uid}/profile_$timestamp.jpg",
        );
      }

      final String name =
      nameController.text.trim();

      final String surname =
      surnameController.text.trim();

      final String profileName =
          "$name ${surname[0].toUpperCase()}.";

      final bool verificationRequested =
          verificationUploaded &&
              identityFrontUrl != null &&
              identityBackUrl != null &&
              criminalRecordUrl != null &&
              selfieUrl != null;

      final SessionInfo session =
      await SessionService.getOrCreateCurrentSession();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "uid": user.uid,
        "ad": name,
        "soyad": surname,
        "profilAdi": profileName,
        "telefon": user.phoneNumber ?? "",
        "dogumTarihi":
        Timestamp.fromDate(birthDate!),
        "yas": calculateAge(birthDate!),
        "cinsiyet": selectedGender ?? "",
        "sehir":
        cityController.text.trim(),
        "ilce":
        districtController.text.trim(),
        "hakkimda":
        aboutController.text.trim(),
        "profilFotografi":
        profilePhotoUrl,
        "avatarUrl": profilePhotoUrl.isEmpty ? selectedAvatarUrl : "",
        "latitude": 0.0,
        "longitude": 0.0,
        "puan": 0.0,
        "plus": false,
        "accountStatus": "active",
        "lastLoginAt": FieldValue.serverTimestamp(),
        "lastLoginPlatform": session.platform,
        "lastLoginAppVersion": session.appVersion,
        "lastDeviceId": session.deviceId,
        "activeSessionId": session.sessionId,
        "verified": false,
        "verificationStatus":
        verificationRequested
            ? "pending"
            : "none",
        "verificationSkipped":
        verificationSkipped ||
            !verificationRequested,
        "oyunlar": selectedGameNames,
        "gameIds": selectedGameLevels.keys.toList(),
        "gameSkills": selectedGameSkillsMap,
        "onboardingCompleted": true,
        "olusturmaTarihi":
        FieldValue.serverTimestamp(),
        "guncellemeTarihi":
        FieldValue.serverTimestamp(),
      });

      if (verificationRequested) {
        final HttpsCallable callable =
        FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('submitVerification');

        await callable.call(<String, dynamic>{
          'identityFrontUrl': identityFrontUrl,
          'identityBackUrl': identityBackUrl,
          'criminalRecordUrl': criminalRecordUrl,
          'selfieUrl': selfieUrl,
        });
            }

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            userName: profileName,
          ),
        ),
            (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      showMessage(
        text.profileCreationError(error),
      );
    }
  }

  void previousPage() {
    if (loading || currentStep == 0) {
      return;
    }

    pageController.previousPage(
      duration: const Duration(
        milliseconds: 300,
      ),
      curve: Curves.easeInOut,
    );
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (
          BuildContext context,
          AppLanguage selectedLanguage,
          Widget? child,
          ) {
        return PopScope<Object?>(
          canPop: currentStep == 0,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop && currentStep > 0) {
              previousPage();
            }
          },
          child: Scaffold(
            backgroundColor:
            const Color(0xff0F1115),
            appBar: AppBar(
              backgroundColor:
              const Color(0xff0F1115),
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading:
              currentStep == 0,
              leading: currentStep > 0
                  ? IconButton(
                onPressed: previousPage,
                icon: const Icon(
                  Icons.arrow_back,
                ),
              )
                  : null,
              title: Text(
                text.createProfile,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  _stepIndicator(),
                  Expanded(
                    child: PageView(
                      controller: pageController,
                      physics:
                      const NeverScrollableScrollPhysics(),
                      onPageChanged: (int page) {
                        setState(() {
                          currentStep = page;
                        });
                      },
                      children: [
                        _profileStep(),
                        _verificationStep(),
                        _gamesStep(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stepIndicator() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        12,
        24,
        18,
      ),
      child: Row(
        children:
        List.generate(3, (int index) {
          final bool active =
              index <= currentStep;

          return Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsets.only(
                right: index == 2 ? 0 : 8,
              ),
              decoration: BoxDecoration(
                color: active
                    ? Colors.orange
                    : Colors.white12,
                borderRadius:
                BorderRadius.circular(20),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<String?> _showLocationPicker({
    required String title,
    required List<String> items,
    required String selectedValue,
    required IconData icon,
  }) async {
    if (!mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff171A20),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (BuildContext sheetContext) {
        String search = '';

        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setModalState,
              ) {
            final String normalizedSearch = search.toLowerCase();
            final List<String> filtered = items
                .where(
                  (String item) =>
                  item.toLowerCase().contains(normalizedSearch),
            )
                .toList();

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.82,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        autofocus: true,
                        onChanged: (String value) {
                          setModalState(() {
                            search = value.trim();
                          });
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: title,
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.orange,
                          ),
                          filled: true,
                          fillColor: const Color(0xff22252C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                          child: Text(
                            'Sonuç bulunamadı',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                            : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(
                            color: Colors.white10,
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final String item = filtered[index];
                            final bool selected = item == selectedValue;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              leading: Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.location_on_outlined,
                                color: selected
                                    ? Colors.orange
                                    : Colors.white38,
                              ),
                              title: Text(
                                item,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext, item);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectCity() async {
    final List<String> cities = await TurkeyLocationService.cities();

    if (!mounted) return;

    if (cities.isEmpty) {
      showMessage('Şehir listesi yüklenemedi. Lütfen tekrar dene.');
      return;
    }

    final String? city = await _showLocationPicker(
      title: text.city,
      items: cities,
      selectedValue: cityController.text,
      icon: Icons.location_city_outlined,
    );

    if (city == null || !mounted) return;

    setState(() {
      if (cityController.text != city) {
        districtController.clear();
      }
      cityController.text = city;
    });
  }

  Future<void> _selectDistrict() async {
    final String city = cityController.text.trim();

    if (city.isEmpty) {
      showMessage(text.enterCity);
      return;
    }

    final List<String> districts =
    await TurkeyLocationService.districtsOf(city);

    if (!mounted) return;

    if (districts.isEmpty) {
      showMessage('Bu şehir için ilçe listesi yüklenemedi.');
      return;
    }

    final String? district = await _showLocationPicker(
      title: text.district,
      items: districts,
      selectedValue: districtController.text,
      icon: Icons.location_on_outlined,
    );

    if (district == null || !mounted) return;

    setState(() {
      districtController.text = district;
    });
  }

  Widget _locationField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(
          hint: hint,
          icon: icon,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.text.isEmpty ? hint : controller.text,
                style: TextStyle(
                  color: controller.text.isEmpty
                      ? Colors.white54
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileStep() {
    return SingleChildScrollView(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        4,
        24,
        30,
      ),
      child: Column(
        children: [
          Text(
            text.basicInformation,
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text.basicInformationDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: loading
                ? null
                : selectProfilePhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 53,
                  backgroundColor:
                  const Color(0xff22252C),
                  backgroundImage: profilePhoto != null
                      ? FileImage(File(profilePhoto!.path))
                      : selectedAvatarUrl.isNotEmpty
                      ? NetworkImage(selectedAvatarUrl) as ImageProvider
                      : null,
                  child: profilePhoto == null && selectedAvatarUrl.isEmpty
                      ? const Icon(
                    Icons.person,
                    color: Colors.orange,
                    size: 60,
                  )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(
                          0xff0F1115,
                        ),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text.profilePhotoOptional,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: loading ? null : selectAvatar,
            icon: const Icon(Icons.face_6_outlined),
            label: Text(text.select3dAvatar),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
          const SizedBox(height: 24),
          _inputField(
            controller: nameController,
            hint: text.name,
            icon: Icons.person_outline,
            capitalization:
            TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: surnameController,
            hint: text.surname,
            icon: Icons.badge_outlined,
            capitalization:
            TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap:
            loading ? null : selectBirthDate,
            borderRadius:
            BorderRadius.circular(12),
            child: InputDecorator(
              decoration: _inputDecoration(
                hint: text.birthDate,
                icon:
                Icons.calendar_month_outlined,
              ),
              child: Text(
                birthDate == null
                    ? text.birthDate
                    : DateFormat(
                  "dd.MM.yyyy",
                ).format(birthDate!),
                style: TextStyle(
                  color: birthDate == null
                      ? Colors.white54
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text.mustBeEighteen,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedGender,
            dropdownColor:
            const Color(0xff252830),
            iconEnabledColor: Colors.orange,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: _inputDecoration(
              hint: text.gender,
              icon: Icons.people_outline,
            ),
            hint: Text(
              text.gender,
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
            items: genders.map(
                  (String gender) {
                return DropdownMenuItem<String>(
                  value: gender,
                  child: Text(text.genderLabel(gender)),
                );
              },
            ).toList(),
            onChanged: loading
                ? null
                : (String? value) {
              setState(() {
                selectedGender = value;
              });
            },
          ),
          const SizedBox(height: 14),
          _locationField(
            controller: cityController,
            hint: text.city,
            icon: Icons.location_city_outlined,
            onTap: loading ? null : _selectCity,
          ),
          const SizedBox(height: 14),
          _locationField(
            controller: districtController,
            hint: text.district,
            icon: Icons.location_on_outlined,
            onTap: loading ? null : _selectDistrict,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: aboutController,
            hint: text.aboutOptional,
            icon: Icons.notes_outlined,
            maxLines: 4,
            maxLength: 300,
            capitalization:
            TextCapitalization.sentences,
          ),
          const SizedBox(height: 26),
          _mainButton(
            text: text.continueText,
            onPressed:
            goToVerificationStep,
          ),
        ],
      ),
    );
  }

  Widget _verificationStep() {
    return SingleChildScrollView(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        4,
        24,
        30,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Colors.orange,
            size: 72,
          ),
          const SizedBox(height: 18),
          Text(
            text.playerVerification,
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text.verificationDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          _documentCard(
            title: text.identityFront,
            subtitle: identityFront?.name,
            icon: Icons.credit_card,
            selected:
            identityFront != null,
            onTap: selectIdentityFront,
          ),
          const SizedBox(height: 12),
          _documentCard(
            title: text.identityBack,
            subtitle: identityBack?.name,
            icon: Icons.credit_card,
            selected:
            identityBack != null,
            onTap: selectIdentityBack,
          ),
          const SizedBox(height: 12),
          _documentCard(
            title: text.criminalRecord,
            subtitle:
            criminalRecord?.name,
            icon:
            Icons.description_outlined,
            selected:
            criminalRecord != null,
            onTap: selectCriminalRecord,
          ),
          const SizedBox(height: 12),
          _documentCard(
            title: text.takeSelfie,
            subtitle: selfiePhoto == null
                ? null
                : text.selfieReady,
            icon:
            Icons.camera_alt_outlined,
            selected:
            selfiePhoto != null,
            onTap: selectSelfie,
          ),
          const SizedBox(height: 14),
          Text(
            text.supportedFileTypes,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _mainButton(
            text:
            text.uploadDocumentsAndContinue,
            onPressed:
            verificationFilesComplete
                ? uploadVerificationDocuments
                : null,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: loading
                  ? null
                  : skipVerification,
              style: TextButton.styleFrom(
                foregroundColor:
                Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  side: const BorderSide(
                    color: Colors.white24,
                  ),
                ),
              ),
              child: Text(
                text.skipForNow,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gamesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.sports_esports_outlined,
            color: Colors.orange,
            size: 72,
          ),
          const SizedBox(height: 18),
          Text(
            text.yourGamesAndSports,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text.gamesDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text.selectedBranches(selectedGameLevels.length),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 26),
          ...GameCatalog.categories.map(_gameCategorySection),
          const SizedBox(height: 24),
          if (verificationUploaded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text.verificationPendingMessage,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _mainButton(
            text: text.completeProfile,
            onPressed: selectedGameLevels.isEmpty
                ? null
                : createProfile,
          ),
        ],
      ),
    );
  }

  Widget _gameCategorySection(GameCategoryDefinition category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff171A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${category.emoji} ${category.name}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...category.games.map(_gameSkillCard),
        ],
      ),
    );
  }

  Widget _gameSkillCard(GameDefinition game) {
    final int? selectedLevel = selectedGameLevels[game.id];
    final bool selected = selectedLevel != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? Colors.orange.withValues(alpha: 0.09)
            : const Color(0xff1C1F25),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected ? Colors.orange : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: loading
                ? null
                : () {
              setState(() {
                if (selected) {
                  selectedGameLevels.remove(game.id);
                } else {
                  selectedGameLevels[game.id] = 30;
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Text(
                  game.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    game.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.add_circle_outline,
                  color: selected ? Colors.orange : Colors.white38,
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 13),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Row(
              children: GameCatalog.skillLevels.map((skill) {
                final bool active = selectedLevel == skill.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: skill == GameCatalog.skillLevels.last ? 0 : 7,
                    ),
                    child: ChoiceChip(
                      selected: active,
                      showCheckmark: false,
                      label: SizedBox(
                        width: double.infinity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '%${skill.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              text.skillLabel(skill.value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      selectedColor: Colors.orange,
                      backgroundColor: Colors.white10,
                      side: BorderSide(
                        color: active ? Colors.orange : Colors.white12,
                      ),
                      labelStyle: TextStyle(
                        color: active ? Colors.black : Colors.white70,
                      ),
                      onSelected: loading
                          ? null
                          : (_) {
                        setState(() {
                          selectedGameLevels[game.id] = skill.value;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: selectedLevel / 100,
                minHeight: 7,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.orange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _documentCard({
    required String title,
    required String? subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xff191C22),
      borderRadius:
      BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius:
        BorderRadius.circular(14),
        child: Container(
          padding:
          const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Colors.orange
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.orange
                      .withValues(alpha: 0.15)
                      : Colors.white10,
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  selected
                      ? Icons.check_circle
                      : icon,
                  color: selected
                      ? Colors.orange
                      : Colors.white70,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      title,
                      style:
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ??
                          text.tapToSelectDocument,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.orange
                            : Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed:
        loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          disabledBackgroundColor:
          Colors.white12,
          foregroundColor: Colors.black,
          disabledForegroundColor:
          Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
          width: 24,
          height: 24,
          child:
          CircularProgressIndicator(
            color: Colors.black,
            strokeWidth: 2.5,
          ),
        )
            : Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController
    controller,
    required String hint,
    required IconData icon,
    TextCapitalization capitalization =
        TextCapitalization.sentences,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      enabled: !loading,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization:
      capitalization,
      style: const TextStyle(
        color: Colors.white,
      ),
      decoration: _inputDecoration(
        hint: hint,
        icon: icon,
      ).copyWith(
        counterStyle: const TextStyle(
          color: Colors.white38,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white54,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.orange,
      ),
      filled: true,
      fillColor:
      const Color(0xff191C22),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.white10,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.orange,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    nameController.dispose();
    surnameController.dispose();
    cityController.dispose();
    districtController.dispose();
    aboutController.dispose();
    super.dispose();
  }
}

class _CreateProfileText {
  const _CreateProfileText(this.currentLanguage);

  final AppLanguage currentLanguage;

  String _value({
    required String tr,
    required String en,
    required String de,
  }) {
    switch (currentLanguage) {
      case AppLanguage.turkish:
        return tr;
      case AppLanguage.english:
        return en;
      case AppLanguage.german:
        return de;
    }
  }
  String genderLabel(String gender) {
    switch (gender) {
      case 'Kadın':
        return _value(tr: 'Kadın', en: 'Woman', de: 'Frau');
      case 'Erkek':
        return _value(tr: 'Erkek', en: 'Man', de: 'Mann');
      default:
        return _value(
          tr: 'Belirtmek istemiyorum',
          en: 'Prefer not to say',
          de: 'Keine Angabe',
        );
    }
  }

  String skillLabel(int value) {
    switch (value) {
      case 30:
        return _value(tr: 'Başlangıç', en: 'Beginner', de: 'Anfänger');
      case 60:
        return _value(tr: 'Orta', en: 'Intermediate', de: 'Mittel');
      case 90:
        return _value(tr: 'İleri', en: 'Advanced', de: 'Fortgeschritten');
      default:
        return _value(tr: 'Seviye', en: 'Level', de: 'Stufe');
    }
  }

  String selectedBranches(int count) => _value(
    tr: 'Seçili branş: $count',
    en: 'Selected activities: $count',
    de: 'Ausgewählte Aktivitäten: $count',
  );

  String documentUploadError(Object error) => _value(
    tr: 'Belgeler yüklenirken bir hata oluştu: $error',
    en: 'An error occurred while uploading the documents: $error',
    de: 'Beim Hochladen der Dokumente ist ein Fehler aufgetreten: $error',
  );

  String profileCreationError(Object error) => _value(
    tr: 'Profil oluşturulurken bir hata oluştu: $error',
    en: 'An error occurred while creating the profile: $error',
    de: 'Beim Erstellen des Profils ist ein Fehler aufgetreten: $error',
  );

  String get createProfile => _value(tr: 'Profil Oluştur', en: 'Create Profile', de: 'Profil erstellen');
  String get basicInformation => _value(tr: 'Temel Bilgiler', en: 'Basic Information', de: 'Grundinformationen');
  String get basicInformationDescription => _value(tr: 'Seni diğer oyunculara tanıtabileceğimiz bilgileri ekle.', en: 'Add information that helps other players get to know you.', de: 'Füge Informationen hinzu, mit denen andere Spieler dich kennenlernen können.');
  String get profilePhotoOptional => _value(tr: 'Profil fotoğrafı isteğe bağlıdır', en: 'Profile photo is optional', de: 'Das Profilfoto ist optional');
  String get select3dAvatar => _value(tr: '3D avatar seç', en: 'Select 3D avatar', de: '3D-Avatar auswählen');
  String get name => _value(tr: 'Ad', en: 'First name', de: 'Vorname');
  String get surname => _value(tr: 'Soyad', en: 'Last name', de: 'Nachname');
  String get birthDate => _value(tr: 'Doğum tarihi', en: 'Date of birth', de: 'Geburtsdatum');
  String get gender => _value(tr: 'Cinsiyet', en: 'Gender', de: 'Geschlecht');
  String get city => _value(tr: 'Şehir', en: 'City', de: 'Stadt');
  String get district => _value(tr: 'İlçe', en: 'District', de: 'Bezirk');
  String get aboutOptional => _value(tr: 'Hakkımda (isteğe bağlı)', en: 'About me (optional)', de: 'Über mich (optional)');
  String get continueText => _value(tr: 'Devam Et', en: 'Continue', de: 'Weiter');
  String get playerVerification => _value(tr: 'Oyuncu Doğrulama', en: 'Player Verification', de: 'Spielerverifizierung');
  String get verificationDescription => _value(tr: 'Bu adım isteğe bağlıdır. Belgelerin onaylandığında doğrulanmış oyuncu rozeti kazanırsın.', en: 'This step is optional. You will receive a verified player badge after your documents are approved.', de: 'Dieser Schritt ist optional. Nach der Freigabe deiner Dokumente erhältst du ein Abzeichen als verifizierter Spieler.');
  String get identityFront => _value(tr: 'Kimlik Ön Yüzü', en: 'Front of ID', de: 'Vorderseite des Ausweises');
  String get identityBack => _value(tr: 'Kimlik Arka Yüzü', en: 'Back of ID', de: 'Rückseite des Ausweises');
  String get criminalRecord => _value(tr: 'Adli Sicil Belgesi', en: 'Criminal Record Document', de: 'Führungszeugnis');
  String get takeSelfie => _value(tr: 'Selfie Çek', en: 'Take a Selfie', de: 'Selfie aufnehmen');
  String get selfieReady => _value(tr: 'Selfie hazır', en: 'Selfie ready', de: 'Selfie bereit');
  String get supportedFileTypes => _value(tr: 'PDF, JPG veya PNG yükleyebilirsin. Dosya boyutu en fazla 10 MB olabilir.', en: 'You can upload PDF, JPG, or PNG files. The maximum file size is 10 MB.', de: 'Du kannst PDF-, JPG- oder PNG-Dateien hochladen. Die maximale Dateigröße beträgt 10 MB.');
  String get uploadDocumentsAndContinue => _value(tr: 'Belgeleri Yükle ve Devam Et', en: 'Upload Documents and Continue', de: 'Dokumente hochladen und fortfahren');
  String get skipForNow => _value(tr: 'Şimdilik Atla', en: 'Skip for Now', de: 'Vorerst überspringen');
  String get yourGamesAndSports => _value(tr: 'Oyun ve Sporların', en: 'Your Games and Sports', de: 'Deine Spiele und Sportarten');
  String get gamesDescription => _value(tr: 'Katılmak istediğin oyunları seç ve her biri için seviyeni belirt.', en: 'Select the games you want to join and choose your level for each one.', de: 'Wähle die Spiele aus, an denen du teilnehmen möchtest, und gib für jedes dein Niveau an.');
  String get verificationPendingMessage => _value(tr: 'Doğrulama belgelerin incelendikten sonra rozetin hesabına eklenecek.', en: 'Your badge will be added to your account after your verification documents are reviewed.', de: 'Dein Abzeichen wird deinem Konto hinzugefügt, nachdem deine Verifizierungsdokumente geprüft wurden.');
  String get completeProfile => _value(tr: 'Profili Tamamla', en: 'Complete Profile', de: 'Profil abschließen');
  String get tapToSelectDocument => _value(tr: 'Belge seçmek için dokun', en: 'Tap to select a document', de: 'Tippen, um ein Dokument auszuwählen');

  String get selectBirthDate => _value(tr: 'Doğum tarihini seç', en: 'Select date of birth', de: 'Geburtsdatum auswählen');
  String get cancel => _value(tr: 'İptal', en: 'Cancel', de: 'Abbrechen');
  String get select => _value(tr: 'Seç', en: 'Select', de: 'Auswählen');
  String get ageRestriction => _value(tr: 'Dördüncü uygulamasına yalnızca 18 yaşını doldurmuş kişiler kayıt olabilir.', en: 'Only people aged 18 or older can register for Dördüncü.', de: 'Bei Dördüncü können sich nur Personen ab 18 Jahren registrieren.');
  String get profilePhotoCouldNotBeSelected => _value(tr: 'Profil fotoğrafı seçilemedi.', en: 'The profile photo could not be selected.', de: 'Das Profilfoto konnte nicht ausgewählt werden.');
  String get selfieCouldNotBeTaken => _value(tr: 'Selfie çekilemedi.', en: 'The selfie could not be taken.', de: 'Das Selfie konnte nicht aufgenommen werden.');
  String get selectedFileCouldNotBeAccessed => _value(tr: 'Seçilen dosyaya erişilemedi.', en: 'The selected file could not be accessed.', de: 'Auf die ausgewählte Datei konnte nicht zugegriffen werden.');
  String get maximumFileSize => _value(tr: 'Dosya boyutu en fazla 10 MB olabilir.', en: 'The maximum file size is 10 MB.', de: 'Die maximale Dateigröße beträgt 10 MB.');
  String get documentSelectionError => _value(tr: 'Belge seçilirken bir hata oluştu.', en: 'An error occurred while selecting the document.', de: 'Beim Auswählen des Dokuments ist ein Fehler aufgetreten.');
  String get enterName => _value(tr: 'Adını gir.', en: 'Enter your first name.', de: 'Gib deinen Vornamen ein.');
  String get enterSurname => _value(tr: 'Soyadını gir.', en: 'Enter your last name.', de: 'Gib deinen Nachnamen ein.');
  String get selectBirthDateValidation => _value(tr: 'Doğum tarihini seç.', en: 'Select your date of birth.', de: 'Wähle dein Geburtsdatum aus.');
  String get selectGender => _value(tr: 'Cinsiyet seçimini yap.', en: 'Select your gender.', de: 'Wähle dein Geschlecht aus.');
  String get enterCity => _value(tr: 'Şehir bilgisini gir.', en: 'Enter your city.', de: 'Gib deine Stadt ein.');
  String get enterDistrict => _value(tr: 'İlçe bilgisini gir.', en: 'Enter your district.', de: 'Gib deinen Bezirk ein.');
  String get addAllVerificationFiles => _value(tr: 'Kimlik ön yüzü, kimlik arka yüzü, adli sicil belgesi ve selfie eklemelisin.', en: 'Add the front and back of your ID, a criminal record document, and a selfie.', de: 'Füge die Vorder- und Rückseite deines Ausweises, ein Führungszeugnis und ein Selfie hinzu.');
  String get userSessionNotFound => _value(tr: 'Kullanıcı oturumu bulunamadı.', en: 'The user session could not be found.', de: 'Die Benutzersitzung wurde nicht gefunden.');
  String get selectAtLeastOneGame => _value(tr: 'En az bir oyun veya spor seç.', en: 'Select at least one game or sport.', de: 'Wähle mindestens ein Spiel oder eine Sportart aus.');
  String get birthDateNotFound => _value(tr: 'Doğum tarihi bulunamadı.', en: 'The date of birth could not be found.', de: 'Das Geburtsdatum wurde nicht gefunden.');
  String get mustBeEighteen => _value(tr: 'Kayıt olabilmek için 18 yaşını doldurmuş olmalısın.', en: 'You must be at least 18 years old to register.', de: 'Du musst mindestens 18 Jahre alt sein, um dich zu registrieren.');
}
