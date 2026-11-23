import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);
    return InputDecorator(
      key: const ValueKey('language-selector'),
      decoration: InputDecoration(
        labelText: AppStrings.language,
        prefixIcon: const Icon(Icons.language),
        isDense: compact,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: controller.language,
          isExpanded: true,
          isDense: compact,
          items: AppLanguage.values
              .map(
                (language) => DropdownMenuItem<AppLanguage>(
                  value: language,
                  child: Text(
                    language.nativeName,
                    textDirection: language.direction,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (language) {
            if (language != null) controller.select(language);
          },
        ),
      ),
    );
  }
}
