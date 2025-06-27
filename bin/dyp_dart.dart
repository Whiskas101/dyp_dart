import 'dart:io';

import 'package:dyp_dart/api/server.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        print('⚠️ Accepting self-signed certificate from $host');
        return true;
      }
      ..findProxy = (uri) {
        print('🔁 Routing $uri through mitmproxy...');
        return "PROXY 127.0.0.1:8080"; // ⚠️ Adjust your mitmproxy port here
      };
  }
}

void main() async {
  // Because the grand standing institution that is my college doesn't have
  // proper ssl setup
  HttpOverrides.global = MyHttpOverrides();

  await startServer();
}
