import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'routes.dart';

HttpServer? _server;

String _address = "127.0.0.1";
int _port = 4321;

Future<void> startServer() async {
  final handler = Pipeline().addHandler(appRoutes);
  print("Starting server at : $_address, $_port");
  _server = await shelf_io.serve(handler, _address, _port);
}

Future<void> stopServer() async {
  await _server?.close(force: true);
  _server = null;
}
