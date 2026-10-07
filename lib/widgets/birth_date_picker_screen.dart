import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/language_controller.dart';

int registrationAge(DateTime date, {DateTime? today}) {
  final DateTime now = today ?? DateTime.now();
  int age = now.year - date.year;
  final bool birthdayPassed =
      now.month > date.month ||
      (now.month == date.month && now.day >= date.day);

  if (!birthdayPassed) {
    age--;
  }

  return age;
}

class BirthDatePickerScreen extends StatefulWidget {
  const BirthDatePickerScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<BirthDatePickerScreen> createState() => _BirthDatePickerScreenState();
}

class _BirthDatePickerScreenState extends State<BirthDatePickerScreen> {
  late final DateTime _minimumDate;
  late final DateTime _maximumDate;
  late final DateTime _wheelDate;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final DateTime today = DateTime.now();
    _minimumDate = DateTime(1900, 1, 1);
    _maximumDate = DateTime(today.year, today.month, today.day, 23, 59);
    _wheelDate = _clamp(_dateOnly(widget.initialDate));
    _selectedDate = widget.initialDate == null ? null : _wheelDate;
  }

  DateTime _defaultWheelDate() {
    final DateTime today = DateTime.now();
    return DateTime(today.year - 20, today.month, 1);
  }

  DateTime _dateOnly(DateTime? value) {
    if (value == null) {
      return _defaultWheelDate();
    }
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _clamp(DateTime value) {
    if (value.isBefore(_minimumDate)) {
      return _minimumDate;
    }
    if (value.isAfter(_maximumDate)) {
      return _maximumDate;
    }
    return value;
  }

  bool get _isAdult {
    final DateTime? selected = _selectedDate;
    if (selected == null) {
      return false;
    }
    return registrationAge(selected) >= 18;
  }

  void _continue() {
    final DateTime? selected = _selectedDate;
    if (selected == null || registrationAge(selected) < 18) {
      return;
    }
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageController.language,
      builder: (BuildContext context, AppLanguage language, Widget? child) {
        return _buildScreen(context, language);
      },
    );
  }

  Widget _buildScreen(BuildContext context, AppLanguage language) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateTime? selected = _selectedDate;
    final bool showAgeWarning = selected != null && !_isAdult;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _copy(
                        language,
                        tr: 'Doğum tarihin ne zaman?',
                        en: 'When is your birthday?',
                        de: 'Wann hast du Geburtstag?',
                      ),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _copy(
                        language,
                        tr: 'Doğum tarihin profilinde herkese açık gösterilmez.',
                        en: 'Your birthday is not shown publicly on your profile.',
                        de: 'Dein Geburtsdatum wird in deinem Profil nicht öffentlich angezeigt.',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      selected == null
                          ? _copy(
                              language,
                              tr: 'Tarih seç',
                              en: 'Select a date',
                              de: 'Datum wählen',
                            )
                          : _formatDate(selected, language),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: selected == null
                                ? colors.onSurfaceVariant
                                : colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (showAgeWarning) ...[
                      const SizedBox(height: 12),
                      Text(
                        _copy(
                          language,
                          tr: 'Dört. uygulamasına yalnızca 18 yaşını doldurmuş kişiler kayıt olabilir.',
                          en: 'Only people aged 18 or older can register for Dört.',
                          de: 'Bei Dört. können sich nur Personen ab 18 Jahren registrieren.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Theme.of(context).brightness,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _wheelDate,
                    minimumDate: _minimumDate,
                    maximumDate: _maximumDate,
                    itemExtent: 40,
                    onDateTimeChanged: (DateTime value) {
                      setState(() {
                        _selectedDate = DateTime(
                          value.year,
                          value.month,
                          value.day,
                        );
                      });
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: FilledButton(
                onPressed: _isAdult ? _continue : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: colors.primary,
                  disabledBackgroundColor: colors.onSurface.withValues(
                    alpha: 0.12,
                  ),
                  foregroundColor: colors.onPrimary,
                  disabledForegroundColor: colors.onSurface.withValues(
                    alpha: 0.38,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(
                  _copy(language, tr: 'Devam', en: 'Continue', de: 'Weiter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLanguage language) {
    return '${date.day} ${_monthName(date.month, language)} ${date.year}';
  }
}

String _copy(
  AppLanguage language, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (language) {
    case AppLanguage.english:
      return en;
    case AppLanguage.german:
      return de;
    case AppLanguage.turkish:
      return tr;
  }
}

String _monthName(int month, AppLanguage language) {
  const List<String> turkish = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  const List<String> english = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const List<String> german = <String>[
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  final List<String> names = switch (language) {
    AppLanguage.english => english,
    AppLanguage.german => german,
    AppLanguage.turkish => turkish,
  };
  return names[month - 1];
}
