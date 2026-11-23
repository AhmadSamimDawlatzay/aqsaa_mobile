import 'package:flutter/material.dart';

enum AppLanguage {
  pashto('ps', 'ps', 'پښتو', TextDirection.rtl),
  dari('fa', 'fa', 'دری', TextDirection.rtl),
  arabic('ar', 'ar', 'العربية', TextDirection.rtl),
  english('en', 'en', 'English', TextDirection.ltr);

  const AppLanguage(
    this.flutterCode,
    this.backendCode,
    this.nativeName,
    this.direction,
  );
  final String flutterCode;
  final String backendCode;
  final String nativeName;
  final TextDirection direction;
  Locale get locale => Locale(flutterCode);

  static AppLanguage fromCode(String? code) => switch (code?.toLowerCase()) {
    'fa' || 'dr' => AppLanguage.dari,
    'ar' => AppLanguage.arabic,
    'en' => AppLanguage.english,
    _ => AppLanguage.pashto,
  };
}
