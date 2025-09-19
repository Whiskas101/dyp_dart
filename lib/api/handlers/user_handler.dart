import 'dart:convert';

import 'package:dyp_dart/api/parser/parser.dart';
import 'package:shelf/shelf.dart';
import 'package:dyp_dart/api/secrets/SITE.dart' as SITE;
import 'package:http/http.dart' as http;

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

    final streamed = await client.send(req);
    // print('streamed headers: ${streamed.headers}');
    final res = await http.Response.fromStream(streamed);
    print('response from site: redirect??; ${res.headers}  ${res.statusCode}');
    print(res.statusCode);
    if ((res.statusCode == 303)) {
      final responseCookies = res.headers['set-cookie'];

      if (responseCookies != null) {
        store.storeFromResponse(res);
        // 1. Extract just the session ID value from the full cookie string.
        // e.g., from "MoodleSession=abcde12345; path=/rait/" we get "abcde12345"
        print("LOCAL SERVER: response cookies: ${responseCookies}");
        // FOR SOME GODDAMN WEIRD REASON, TWO OF THE SAME COOKIES ARE SENT BACK, & OVERWRITTEN INSTANTLY.
        // Extract the SECOND one to actually have a valid session cookie returned to the application
        final sessionValue = responseCookies.split(';')[1].split('=').last;

        // 2. Create the JSON payload that the client expects.
        final responsePayload = {
          'MoodleSession': sessionValue,
        };

        final String jsonBody = jsonEncode(responsePayload);

        // 3. Prepare the headers for the client, passing through the original cookie.
        final responseHeaders = {
          'Content-Type': 'application/json',
          'set-cookie': responseCookies,
        };

        // 4. Return the complete response object.
        return Response.ok(jsonBody, headers: responseHeaders);
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

  //TODO: Add try and catch block and handle failure case with correst response
  // codes
  final streamed = await client.send(req);
  final res = await http.Response.fromStream(streamed);
  print(res.toString());
  String htmlResponse = res.body.toString();

  String subjects = parseSubjects(htmlResponse);
  return Response.ok(subjects);
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
    String htmlResponse = res.body.toString();

    String materials = parseMaterials(htmlResponse);

    return Response.ok(materials);
  } catch (err) {
    return Response.internalServerError(body: "Something went wrong");
  }
}

Future<Response> getDownloadLink(Request request) async {
  final body = await request.readAsString();

  try {
    final data = Uri.splitQueryString(body);
    final targetLink = data['link'];
    final linkType = data['type'];

    if (targetLink == null || linkType == null) {
      return Response.badRequest(body: "Missing link/type parameter!");
    }

    final targetUri = Uri.parse(targetLink);

    http.Request req = http.Request('GET', targetUri)
      ..headers.addAll({
        'Cookie': store.MoodleSessionCookie,
      });

    final client = http.Client();

    final streamed = await client.send(req);
    final res = await http.Response.fromStream(streamed);
    print(res.body.toString());
    String htmlResponse = res.body.toString();

    String downloadLink = parseResourceLink(htmlResponse, linkType);
    print(downloadLink);

    if (downloadLink.isEmpty) {
      return Response.internalServerError(
          body: "Could not parse the download link!");
    }

    return Response.ok(downloadLink);

    //
  } catch (err) {
    return Response.internalServerError(body: "Something went wrong");
  }
}

// jsonified timetable
Future<Response> getTimetable(Request request) async {
  try {
    http.Request req = http.Request('GET', SITE.TIMETABLE_URL)
      ..headers.addAll({
        'Cookie': store.MoodleSessionCookie,
      });

    final client = http.Client();

    final streamed = await client.send(req);
    final res = await http.Response.fromStream(streamed);
    print(res.toString());

    final htmlResponse = res.body.toString();

    final String timetable = parseTimetable(htmlResponse);

    return Response.ok(timetable);
    //
  } catch (err) {
    return Response.internalServerError(body: "Something went wrong");
  }
  return Response.ok("{'fuc':'isthis'}");
}

// json object contained computed data about how many classes you can skip
Future<Response> getAttendanceSummary(Request request) async {
  try {
    http.Request req = http.Request('GET', SITE.ATTENDANCE_URL)
      ..headers.addAll({
        'Cookie': store.MoodleSessionCookie,
      });

    final client = http.Client();

    final streamed = await client.send(req);
    final res = await http.Response.fromStream(streamed);
    print(res.toString());

    final htmlResponse = res.body.toString();

    final String attendanceSummary = parseAttendance(htmlResponse);

    return Response.ok(attendanceSummary);
    //
  } catch (err) {
    return Response.internalServerError(body: "Something went wrong");
  }
  return Response.ok("{'fuc':'isthis'}");
}
