import 'dart:io';
import 'dart:isolate';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'routes.dart'; // Your routes file


class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        print(
            '⚠️ Server Isolate: Accepting self-signed certificate from $host');
        return true;
      }
      ..findProxy = (uri) {
        print('🔁 Server Isolate: Routing $uri through mitmproxy...');
        return "PROXY 127.0.0.1:8080";
      };
  }
}

Future<void> serverEntryPoint(SendPort mainSendPort) async {
  HttpOverrides.global = MyHttpOverrides();


  final commandPort = ReceivePort();
  HttpServer? server;

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(appRoutes);

  server = await shelf_io.serve(handler, '127.0.0.1', 0);
  print('✅ Server started on port ${server.port}');

  mainSendPort.send({
    'port': server.port,
    'commandPort': commandPort.sendPort,
  });

  await for (final message in commandPort) {
    if (message == 'stop') {
      print(' shutting down server...');
      await server?.close(force: true);
      commandPort.close();
      break;
    }
  }

  print('🛑 Server isolate finished.');
}



