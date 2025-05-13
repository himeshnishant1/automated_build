import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:intl/intl.dart';

void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('pubspec.yaml not found!');
    return;
  }

  final yamlString = pubspecFile.readAsStringSync();
  final pubspec = loadYaml(yamlString);

  final appName = pubspec['name'];
  final version = pubspec['version'];

  if (appName == null || appName.trim().isEmpty) {
    print('App name not found in pubspec.yaml!');
    return;
  }
  if (version == null || version.trim().isEmpty) {
    print('App version not found in pubspec.yaml!');
    return;
  }

  final apkDir = Directory('build/app/outputs/flutter-apk');
  final originalApk = File('${apkDir.path}/app-release.apk');

  if (!originalApk.existsSync()) {
    print('APK not found: ${originalApk.path}');
    return;
  }

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  // Clean version string for filename (e.g., 1.0.0+1 -> 1.0.0_1)
  final versionSanitized = version.replaceAll('+', '_');

  final newApkName = '${appName}_v${versionSanitized}_$timestamp.apk';
  final newApkPath = '${apkDir.path}/$newApkName';

  await originalApk.rename(newApkPath);
  print('APK renamed to: $newApkPath');
}
