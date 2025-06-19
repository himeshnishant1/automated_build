import 'package:package_info_plus/package_info_plus.dart';

class PackageName {
  static Future<String> getPackageName() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String packageName = packageInfo.packageName;

    return packageName;
  }

  static Future<String> setAssetPath() async{
    String packageName = await getPackageName();
    if(packageName == "com.example.test_name001"){
      return "apple-white.png";
    }
    return "playstore-white.png";
  }
}