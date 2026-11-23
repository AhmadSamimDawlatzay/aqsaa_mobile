import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class PashtoCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const PashtoCupertinoLocalizations();

  @override
  String get todayLabel => 'نن';
  @override
  String get alertDialogLabel => 'خبرتیا';
  @override
  String get cutButtonLabel => 'پرې کول';
  @override
  String get copyButtonLabel => 'کاپي';
  @override
  String get pasteButtonLabel => 'نښلول';
  @override
  String get clearButtonLabel => 'پاکول';
  @override
  String get selectAllButtonLabel => 'ټول ټاکل';
  @override
  String get lookUpButtonLabel => 'لټول';
  @override
  String get searchWebButtonLabel => 'په وېب کې لټون';
  @override
  String get shareButtonLabel => 'شریکول';
  @override
  String get searchTextFieldPlaceholderLabel => 'لټون';
  @override
  String get modalBarrierDismissLabel => 'بندول';
  @override
  String get menuDismissLabel => 'غورنۍ بندول';
  @override
  String get cancelButtonLabel => 'لغوه';
  @override
  String get backButtonLabel => 'شاته';
  @override
  String get expansionTileExpandedHint => 'د تړلو لپاره دوه ځله ټک وکړئ';
  @override
  String get expansionTileCollapsedHint => 'د پرانیستلو لپاره دوه ځله ټک وکړئ';
  @override
  String get expansionTileExpandedTapHint => 'تړل';
  @override
  String get expansionTileCollapsedTapHint => 'نور معلومات پرانیستل';
  @override
  String tabSemanticsLabel({required int tabIndex, required int tabCount}) =>
      'ټوپ $tabIndex له $tabCount څخه';
}

class PashtoCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const PashtoCupertinoLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ps';
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const PashtoCupertinoLocalizations());
  @override
  bool shouldReload(PashtoCupertinoLocalizationsDelegate old) => false;
}
