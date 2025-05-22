import 'dart:io';
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  try {
    print('🚀 Starting app configuration...');

    // Read config.yaml file
    final config = await readConfig();

    // Extract values from config
    final appName = config['application_name']?.toString() ?? '';
    final flavor = validateFlavor(config['flavor']);
    final packageName = config['packageName']?.toString() ?? '';
    final version = config['version']?.toString() ?? '';
    final buildNumber = config['build']?.toString() ?? '';

    // Validate required fields
    if (appName.isEmpty ||
        flavor.isEmpty ||
        packageName.isEmpty ||
        version.isEmpty ||
        buildNumber.isEmpty) {
      throw Exception('Missing required fields in config.yaml');
    }

    print('📋 Configuration loaded:');
    print('   App Name: $appName');
    print('   Flavor: $flavor');
    print('   Package Name: $packageName');
    print('   Version: $version');
    print('   Build Number: $buildNumber');

    // Perform updates
    await updatePubspecYaml(appName, flavor, version, buildNumber);
    await updateAndroidPackageName(packageName, appName);
    await updateIosPackageName(packageName);

    print('✅ App configuration completed successfully!');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

String validateFlavor(String? flavor) {
  return (flavor == null ||
          !(flavor == 'prod' || flavor == 'uat' || flavor == 'dev'))
      ? 'pod'
      : flavor;
}

Future<void> runPubGet() async{
  // Run flutter pub get
  final pubGetResult = await Process.run('flutter', ['pub', 'get']);
  if (pubGetResult.exitCode != 0) {
    print('❌ Failed to run flutter pub get:\n${pubGetResult.stderr}');
    return;
  }
  print('✅ flutter pub get completed');
}

Future<Map<String, dynamic>> readConfig() async {
  final configFile = File('config.yaml');

  if (!configFile.existsSync()) {
    throw Exception('config.yaml file not found in root directory');
  }

  final configContent = await configFile.readAsString();
  final yamlDoc = loadYaml(configContent);

  if (yamlDoc is! Map) {
    throw Exception('Invalid config.yaml format');
  }

  return Map<String, dynamic>.from(yamlDoc);
}

Future<void> updateLauncherIconPath(String flavor) async {
  final pubspecFile = File('pubspec.yaml');
  String content = await pubspecFile.readAsString();

  final regex = RegExp(
      r"(flutter_launcher_icons:\s*[\s\S]*?image_path:\s*['\'])([^'\']+)(['\'])",
      multiLine: true);

  final newImagePath = 'assets/app_icons/app_$flavor.png';

  final newContent = content.replaceFirstMapped(regex, (match) {
    return '${match[1]}$newImagePath${match[3]}';
  });

  await pubspecFile.writeAsString(newContent);
  print('✅ pubspec.yaml updated with image_path: $newImagePath');

  // Run flutter pub get
  await runPubGet();

  // Run flutter_launcher_icons
  final launcherIconResult =
      await Process.run('dart', ['run', 'flutter_launcher_icons']);
  if (launcherIconResult.exitCode != 0) {
    print(
        '❌ Failed to run flutter_launcher_icons:\n${launcherIconResult.stderr}');
    return;
  }
  print('✅ flutter_launcher_icons executed successfully');
}

Future<void> updatePubspecYaml(
    String appName, String flavor, String version, String buildNumber) async {
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    throw Exception('pubspec.yaml not found');
  }

  String content = await pubspecFile.readAsString();

  // Update name
  content = content.replaceFirstMapped(
    RegExp(r'^name:\s*.*$', multiLine: true),
    (match) => 'name: $appName',
  );

  // Update defaultEnv (assuming it's in the format "defaultEnv: flavor")
  content = content.replaceFirstMapped(
    RegExp(r'^(\s*)defaultEnv:\s*.*$', multiLine: true),
    (match) => '${match.group(1)}defaultEnv: $flavor',
  );

  // Update version with build number
  content = content.replaceFirstMapped(
    RegExp(r'^version:\s*[\d.]+(\+\d+)?$', multiLine: true),
    (match) => 'version: $version+$buildNumber',
  );

  await pubspecFile.writeAsString(content);

  await updateLauncherIconPath(flavor);

  print('📦 Updated pubspec.yaml');
}

Future<void> updateAndroidPackageName(
    String packageName, String appName) async {
  print('🤖 Updating Android package name...');

  // Update all Android-related files manually
  await updateAndroidManifest(packageName, appName);
  await updateBuildGradle(packageName);
  await updateMainActivity(packageName);
  await updatePackageReferencesInBuildGradle(packageName);
  // await updateManifestPackage(packageName);
  await updateAndroidStrings(); // Add this to create/update strings.xml

  print('✅ Updated Android package name to $packageName');
}

Future<void> updatePackageReferencesInBuildGradle(String newPackageName) async {
  final buildGradleFile = File('android/app/build.gradle');
  if (!buildGradleFile.existsSync()) {
    print('⚠️ android/app/build.gradle not found.');
    return;
  }

  String content = await buildGradleFile.readAsString();
  bool modified = false;

  // Update applicationId
  final appIdRegex = RegExp(r'applicationId\s+"[^"]+"');
  if (appIdRegex.hasMatch(content)) {
    content =
        content.replaceFirst(appIdRegex, 'applicationId "$newPackageName"');
    print('✅ applicationId updated.');
    modified = true;
  } else {
    print('ℹ️ No applicationId found to replace.');
  }

  // Update namespace
  final namespaceRegex =
      RegExp(r"^\s*namespace\s+['\']([^'\']+)['\']", multiLine: true);
  if (namespaceRegex.hasMatch(content)) {
    content =
        content.replaceFirst(namespaceRegex, 'namespace "$newPackageName"');
    print('✅ namespace updated.');
    modified = true;
  } else {
    print('ℹ️ No namespace found to replace.');
  }

  if (modified) {
    await buildGradleFile.writeAsString(content);
    print(
        '🎉 build.gradle updated successfully with new package name "$newPackageName".');
  } else {
    print('⚠️ No changes made to build.gradle.');
  }
}

Future<void> updateAndroidManifest(String packageName, String appName) async {
  final manifestPath = 'android/app/src/main/AndroidManifest.xml';
  final manifestFile = File(manifestPath);

  if (!manifestFile.existsSync()) {
    print('⚠️  Warning: AndroidManifest.xml not found at $manifestPath');
    return;
  }

  String content = await manifestFile.readAsString();

  // Update package attribute in manifest tag
  content = content.replaceFirstMapped(
    RegExp(r'<manifest[^>]*package="[^"]*"'),
    (match) {
      final beforePackage = match.group(0)!.split('package="')[0];
      return '${beforePackage}package="$packageName"';
    },
  );

  // Update android:label attribute to use string resource
  content = content.replaceFirstMapped(
    RegExp(r'android:label="[^"]*"'),
    (match) => 'android:label="$appName"',
  );

  await manifestFile.writeAsString(content);
  print('✅ Updated AndroidManifest.xml package name and label');
}

Future<void> updateAndroidStrings() async {
  final stringsPath = 'android/app/src/main/res/values/strings.xml';
  final stringsFile = File(stringsPath);

  // Get app name from our config
  final config = await readConfig();
  final appName = config['application_name'] as String? ?? 'MyApp';

  // Create the strings.xml content
  final stringsContent = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$appName</string>
</resources>''';

  // Create directory if it doesn't exist
  await stringsFile.parent.create(recursive: true);

  if (stringsFile.existsSync()) {
    // Update existing strings.xml
    String content = await stringsFile.readAsString();

    if (content.contains('name="app_name"')) {
      // Update existing app_name
      content = content.replaceFirstMapped(
        RegExp(r'<string name="app_name">[^<]*</string>'),
        (match) => '<string name="app_name">$appName</string>',
      );
    } else {
      // Add app_name to existing resources
      content = content.replaceFirstMapped(
        RegExp(r'</resources>'),
        (match) =>
            '    <string name="app_name">$appName</string>\n</resources>',
      );
    }

    await stringsFile.writeAsString(content);
  } else {
    // Create new strings.xml file
    await stringsFile.writeAsString(stringsContent);
  }

  print('✅ Updated/Created strings.xml with app_name');
}

Future<void> updateIosPackageName(String packageName) async {
  // Update iOS bundle identifier in project.pbxproj
  final pbxprojPath = 'ios/Runner.xcodeproj/project.pbxproj';
  final pbxprojFile = File(pbxprojPath);

  if (!pbxprojFile.existsSync()) {
    print('⚠️  Warning: project.pbxproj not found at $pbxprojPath');
    return;
  }

  String content = await pbxprojFile.readAsString();

  // Update PRODUCT_BUNDLE_IDENTIFIER while preserving suffixes like .RunnerTests
  content = content.replaceAllMapped(
    RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);'),
    (match) {
      final oldValue = match.group(1)!.trim();

      // Check if there's a suffix after the main bundle ID
      final suffixes = ['.RunnerTests', '.UITests', '.Tests'];
      String suffix = '';

      for (final s in suffixes) {
        if (oldValue.endsWith(s)) {
          suffix = s;
          break;
        }
      }

      return 'PRODUCT_BUNDLE_IDENTIFIER = $packageName$suffix;';
    },
  );

  await pbxprojFile.writeAsString(content);
  print(
      '🍏 Updated iOS bundle identifier to $packageName (with preserved suffixes)');
}

Future<void> updateBuildGradle(String packageName) async {
  final buildGradlePath = 'android/app/build.gradle';
  final buildGradleFile = File(buildGradlePath);

  if (!buildGradleFile.existsSync()) {
    print('⚠️  Warning: build.gradle not found at $buildGradlePath');
    return;
  }

  String content = await buildGradleFile.readAsString();

  // Update applicationId
  content = content.replaceFirstMapped(
    RegExp(r"applicationId\s*=?\s*(['\'])([^'\']*)\1", multiLine: true),
    (match) {
      final quote = match.group(1)!;
      return 'applicationId ${quote}${packageName}${quote}';
    },
  );

  await buildGradleFile.writeAsString(content);
  print('✅ Updated build.gradle applicationId');
}

Future<void> updateMainActivity(String newPackageName) async {
  print(
      '📄 Updating MainActivity package declaration, folder structure, and cleaning up...');

  // These are potential language folders for Android sources
  final baseDirs = ['android/app/src/main/kotlin', 'android/app/src/main/java'];

  for (final basePath in baseDirs) {
    final baseDir = Directory(basePath);
    if (!baseDir.existsSync()) continue;

    final mainActivityFiles = await baseDir
        .list(recursive: true)
        .where((entity) =>
            entity is File &&
            (entity.path.endsWith('MainActivity.kt') ||
                entity.path.endsWith('MainActivity.java')))
        .toList();

    if (mainActivityFiles.isEmpty) continue;

    final oldFile = mainActivityFiles.first as File;
    final content = await oldFile.readAsString();

    final packageRegex = RegExp(r'^package\s+([^\s;]+)', multiLine: true);
    final match = packageRegex.firstMatch(content);
    if (match == null) {
      print('⚠️ Could not find package declaration in MainActivity.');
      return;
    }

    final oldPackageName = match.group(1)!;
    final newContent =
        content.replaceFirst(packageRegex, 'package $newPackageName');

    // Build paths
    final oldPackagePath = oldPackageName.replaceAll('.', '/');
    final newPackagePath = newPackageName.replaceAll('.', '/');

    final fileExtension = oldFile.path.endsWith('.kt') ? 'kt' : 'java';

    final oldFilePath = '$basePath/$oldPackagePath/MainActivity.$fileExtension';
    final newDirPath = '$basePath/$newPackagePath';
    final newFilePath = '$newDirPath/MainActivity.$fileExtension';

    // Create new directory
    final newDir = Directory(newDirPath);
    if (!newDir.existsSync()) {
      await newDir.create(recursive: true);
    }

    // Write updated file
    final newFile = File(newFilePath);
    await newFile.writeAsString(newContent);

    // Delete old file
    await oldFile.delete();

    // Cleanup old folders if empty
    await deleteEmptyFolders(Directory('$basePath/$oldPackagePath'));

    print('✅ MainActivity moved from "$oldFilePath" to "$newFilePath"');
    print('✅ Package updated from "$oldPackageName" to "$newPackageName"');
    return;
  }

  print('⚠️ MainActivity file not found in Kotlin/Java source directories.');
}

/// Recursively deletes empty folders up to the root path
Future<void> deleteEmptyFolders(Directory dir) async {
  while (true) {
    if (!dir.existsSync()) break;
    final contents = dir.listSync();
    if (contents.isEmpty) {
      await dir.delete();
      dir = dir.parent;
    } else {
      break;
    }
  }
}

Future<void> _cleanupEmptyDirectories(Directory dir) async {
  try {
    if (await dir.list().isEmpty) {
      await dir.delete();
      // Recursively clean parent if it's also empty
      final parent = dir.parent;
      if (parent.path != dir.path &&
          parent.path.contains('android/app/src/main/')) {
        await _cleanupEmptyDirectories(parent);
      }
    }
  } catch (e) {
    // Ignore cleanup errors
  }
}
