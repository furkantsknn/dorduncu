import '../models/user_model.dart';

/// Kullanıcının kendi doldurduğu profil bilgileri.
///
/// Oyuncu rozeti kimlik doğrulaması ve admin onayıyla yazılır.
/// Satın alma da bu hesaba girmez.
enum ProfileCompletionField { name, photo, about, city, games }

class ProfileCompletion {
  const ProfileCompletion({required this.checks, required this.percent});

  final Map<ProfileCompletionField, bool> checks;
  final int percent;

  bool isComplete(ProfileCompletionField field) => checks[field] == true;

  List<ProfileCompletionField> get missingActions {
    return ProfileCompletionField.values
        .where((ProfileCompletionField field) => !isComplete(field))
        .toList();
  }
}

/// `displayName` boş kayıtta "Kullanıcı" döndürür. O yedek isim sayılmaz.
bool profileNameComplete(UserModel user) {
  return user.profilAdi.trim().isNotEmpty || user.fullName.trim().isNotEmpty;
}

/// Profil şehri `sehir` alanıdır. Ana sayfanın etkinlik filtresi `aktifSehir`
/// bu kontrolü doldurmaz.
bool profileCityComplete(UserModel user) {
  return user.sehir.trim().isNotEmpty;
}

ProfileCompletion profileCompletionOf(UserModel user) {
  final Map<ProfileCompletionField, bool> checks =
      <ProfileCompletionField, bool>{
        ProfileCompletionField.name: profileNameComplete(user),
        ProfileCompletionField.photo: user.profilFotografi.trim().isNotEmpty,
        ProfileCompletionField.about: user.hakkimda.trim().isNotEmpty,
        ProfileCompletionField.city: profileCityComplete(user),
        ProfileCompletionField.games: user.gameSkills.isNotEmpty,
      };
  final int completed = checks.values.where((bool value) => value).length;
  final int percent = ((completed / checks.length) * 100).round();
  return ProfileCompletion(checks: checks, percent: percent);
}

/// Profil düzenleme ekranının yazdığı alanlar.
/// `aktifSehir`, rozet ve doğrulama bu yamaya girmez.
Map<String, dynamic> profileEditorPatch({
  required String name,
  required String city,
  required String previousCity,
  required String photoUrl,
  required String avatarUrl,
  required String about,
  required List<String> gameNames,
  required List<String> gameIds,
  required Map<String, dynamic> gameSkills,
}) {
  final Map<String, dynamic> patch = <String, dynamic>{
    'profilFotografi': photoUrl,
    'avatarUrl': avatarUrl,
    'oyunlar': gameNames,
    'gameIds': gameIds,
    'gameSkills': gameSkills,
    'hakkimda': about.trim(),
  };
  final String trimmedName = name.trim();
  if (trimmedName.isNotEmpty) {
    patch['profilAdi'] = trimmedName;
  }
  final String trimmedCity = city.trim();
  if (trimmedCity.isNotEmpty) {
    patch['sehir'] = trimmedCity;
    if (trimmedCity != previousCity.trim()) {
      patch['ilce'] = '';
    }
  }
  return patch;
}
