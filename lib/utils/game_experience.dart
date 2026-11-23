import 'package:flutter/widgets.dart';

int? normalizeGameExperience(Object? value) {
  final String raw = value?.toString().replaceAll('%', '').trim() ?? '';
  final int? number = value is num ? value.toInt() : int.tryParse(raw);
  return switch (number) {
    30 => 30,
    60 => 60,
    90 => 90,
    _ => null,
  };
}

String gameExperienceLabel(BuildContext context, Object? value) {
  final String language = Localizations.localeOf(context).languageCode;
  final int? level = normalizeGameExperience(value);
  if (level == 30) {
    return switch (language) {
      'en' => 'Beginner',
      'de' => 'Anfänger',
      _ => 'Acemi',
    };
  }
  if (level == 60) {
    return switch (language) {
      'en' => 'Intermediate',
      'de' => 'Mittelstufe',
      _ => 'Orta',
    };
  }
  if (level == 90) {
    return switch (language) {
      'en' => 'Expert',
      'de' => 'Experte',
      _ => 'Usta',
    };
  }
  return switch (language) {
    'en' => 'Not specified',
    'de' => 'Nicht angegeben',
    _ => 'Belirtilmemiş',
  };
}

String selfDeclaredExperienceText(BuildContext context, Object? value) {
  final String label = gameExperienceLabel(context, value);
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => '$label (self-declared)',
    'de' => '$label (Selbstauskunft)',
    _ => '$label (kullanıcı beyanı)',
  };
}
