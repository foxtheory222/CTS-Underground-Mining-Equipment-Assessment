import 'package:flutter/foundation.dart';

@immutable
class AppBuildMetadata {
  const AppBuildMetadata({required this.version, required this.buildDate});

  static const AppBuildMetadata current = AppBuildMetadata(
    version: String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1'),
    buildDate: String.fromEnvironment(
      'BUILD_DATE',
      defaultValue: 'development',
    ),
  );

  final String version;
  final String buildDate;

  String get versionLabel => 'App version $version';

  String get buildDateLabel => buildDate == 'development'
      ? 'Build profile development'
      : 'Build date $buildDate';
}
