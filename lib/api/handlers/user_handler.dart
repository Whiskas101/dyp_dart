import 'dart:io';
import 'dart:mirrors';

import 'package:shelf/shelf.dart';
import 'package:dyp_dart/api/secrets/SITE.dart' as SITE;
import 'package:http/http.dart' as http;
// utility function to help parse the Stream result of request body as JSON
// Future<Map<String, dynamic>?> readAsJSON(Request request) async {
//   final body = await request.readAsString();
//
//   try {
//     final jsonBody = jsonDecode(body);
//     return jsonBody;
//   } catch (e) {
//     throw FormatException("Invalid JSON: $e");
//   }
// }

// A simple class to manage and help propagate
// cookies that are received when redirected or otherwise
class CookieStore {
  final Map<String, String> _cookies = {};

  String get header =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  String get MoodleSessionCookie =>
      'MoodleSession=${_cookies["MoodleSession"]}; path=/rait/';

  void clear() => _cookies.clear();

  bool get isEmpty => _cookies.isEmpty;
  bool get isNotEmpty => _cookies.isNotEmpty;

  // Takes a response object and populates the [_cookies] property
  void storeFromResponse(http.Response res) {
    final setCookieHeaders = res.headers['set-cookie'];
    if (setCookieHeaders == null) return;

    final cookieParts = setCookieHeaders.split(',');

    for (final rawCookie in cookieParts) {
      if (rawCookie.contains('=') && !rawCookie.contains('deleted')) {
        final parts = rawCookie.split(';')[0].split('=');
        if (parts.length == 2) {
          final name = parts[0].trim();
          final value = parts[1].trim();
          _cookies[name] = value;
        }
      }
    }
  }
}

CookieStore store = CookieStore();

Future<Response> login(Request request) async {
  // debugLoginRequest();
  // return Response.ok('what');
  final body = await request.readAsString();

  try {
    final data = Uri.splitQueryString(body);
    final username = data['username'];
    final password = data['password'];
    print("$username, $password");

    Map<String, String> userData = {
      'username': username!,
      'password': password!,
    };

    http.Request req = http.Request('POST', SITE.AUTH_URL)
      ..bodyFields = userData
      ..followRedirects = false;

    print("Req: ${req.toString()} ::: ${req.body.toString()}");

    // Make a login request to the LMS site
    final client = http.Client();

    // http.Response res = await client.post(
    //   SITE.AUTH_URL,
    //   body: userData,
    //   headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    // );

    // final streamed = await client.send(request);

    // print('raw status: ${streamed.statusCode}');

    final streamed = await client.send(req);
    // print('streamed headers: ${streamed.headers}');
    final res = await http.Response.fromStream(streamed);
    print('response from site: redirect??; ${res.headers}  ${res.statusCode}');
    print(res.statusCode);
    if ((res.statusCode == 303)) {
      final responseCookies = res.headers['set-cookie'];
      if (responseCookies != null) {
        store.storeFromResponse(res);
        print(store.MoodleSessionCookie);
        return Response.ok("Logged in!");
      }
    }
    return Response.forbidden("Failed to login!");
  } catch (err) {
    return Response(400, body: 'Failed to login!');
  }
}

Future<Response> getSubjects(Request request) async {
  http.Request req = http.Request('GET', SITE.SUBJECTS_URL)
    ..headers.addAll({
      'Cookie': store.MoodleSessionCookie,
    });

  final client = http.Client();

  final streamed = await client.send(req);
  final res = await http.Response.fromStream(streamed);
  print(res.toString());
  print(res.body.toString());

  return Response.ok("");
}

Future<Response> getMaterials(Request request) async {
  final body = await request.readAsString();

  try {
    final data = Uri.splitQueryString(body);
    final targetLink = data['link'];

    if (targetLink == null) {
      return Response.badRequest(body: "Missing link parameter!");
    }

    final targetUri = Uri.parse(targetLink);

    http.Request req = http.Request('GET', targetUri)
      ..headers.addAll({
        'Cookie': store.MoodleSessionCookie,
      });

    final client = http.Client();

    final streamed = await client.send(req);
    final res = await http.Response.fromStream(streamed);
    print(res.toString());
    print(res.body.toString());
    // TODO: add a parser and return json
  } catch (err) {
    return Response.internalServerError(body: "Something went wrong");
  }

  return Response.ok("");
}

Future<Response> getDownloadLink(Request request) async {
  final body = await request.readAsString();

  try {
    final data = Uri.splitQueryString(body);
    final targetLink = data['link'];

    if (targetLink == null) {
      Response.badRequest(body: "Missing link parameter!");
    }

    final targetUri = Uri.parse(targetLink!);

    http.Request req = http.Request('GET', targetUri)
      ..headers.addAll({
        'Cookie': store.MoodleSessionCookie,
      });

    // TODO: add a parser and return json
    final client = http.Client();

    final streamed = await client.send(req);
    final res = await http.Response.fromStream(streamed);
    print(res.toString());
    print(res.body.toString());

    //
  } catch (err) {
    return Response.internalServerError(body: "Something went wrong");
  }
  return Response.ok("{'fuc':'isthis'}");
}

Future<Response> getAttendanceSummary(Request request) async {
  try {
    http.Request req = http.Request('GET', SITE.ATTENDANCE_URL)
      ..headers.addAll({
        'Cookie': store.MoodleSessionCookie,
      });

    // TODO: add a parser and return json
    final client = http.Client();

    final streamed = await client.send(req);
    final res = await http.Response.fromStream(streamed);
    print(res.toString());
    print(res.body.toString());

    //
  } catch (err) {
    return Response.internalServerError(body: "Something went wrong");
  }
  return Response.ok("{'fuc':'isthis'}");
}
