import 'package:flutter/widgets.dart';
import '../auth/session_store.dart';
import 'app_language.dart';
import 'app_strings.dart';

class LocaleController extends ChangeNotifier {
  LocaleController(this._store) {
    AppStrings.setLanguage(_language);
  }
  static const storageKey = 'aqsaa.locale.v1';
  final SecureKeyValueStore _store;
  AppLanguage _language = AppLanguage.pashto;
  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  String get backendCode => _language.backendCode;

  Future<void> restore() async {
    try {
      _apply(AppLanguage.fromCode(await _store.read(storageKey)));
    } catch (_) {
      // Language preference must never prevent the app from starting.
      _apply(AppLanguage.pashto);
    }
  }

  Future<void> select(AppLanguage language) async {
    if (_language == language) return;
    _apply(language);
    try {
      await _store.write(storageKey, language.backendCode);
    } catch (_) {
      // Keep the in-memory choice usable when platform storage is unavailable.
    }
  }

  void _apply(AppLanguage language) {
    _language = language;
    AppStrings.setLanguage(language);
    notifyListeners();
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}
