import 'dart:convert';

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

/// Returns a JSON string that is an array of subjects
String parseSubjects(String html) {
  final doc = parse(html);
  final subjects = <Map<String, String>>[];

  final subjectContainers = doc.querySelectorAll('.subcontent-container');

  for (var subject in subjectContainers) {
    final String subjectName = subject.querySelector('h4')?.nodes[0].text ?? '';
    final String instructor =
        subject.querySelector('.istruinfocontainer > div')?.text.trim() ?? '';
    final attendance =
        subject.querySelector('.prg-container > span')?.text.trim() ?? '0%';
    final Element? linkTag = subject.querySelector('a');
    final String link = linkTag?.attributes['href'] ?? '';
    final String courseId =
        link.length >= 4 ? link.substring(link.length - 4) : '';

    subjects.add({
      'name': subjectName,
      'instructor': instructor,
      'attendance': attendance,
      'link': link,
      'course_id': courseId,
    });
  }

  return jsonEncode(subjects);
}

/// Returns a JSON string that is an array of materials
String parseMaterials(String html) {
  final doc = parse(html);
  final materials = <Map<String, String>>[];

  final activities = doc.querySelectorAll('.activityinstance');

  for (var activity in activities) {
    final linkTag = activity.querySelector('a');
    final nameTag = activity.querySelector('span');
    final docTypeTag = activity.querySelector('.accesshide');

    final link = linkTag?.attributes['href'] ?? '';
    final name = nameTag?.text.trim() ?? '';
    final type =
        link.length > 53 ? link.substring(34, link.length - 19) : 'unknown';
    final docType = docTypeTag?.text.trim() ?? 'unknown';

    materials.add({
      'name': name,
      'link': link,
      'type': type,
      'doctype': docType,
    });
  }

  return jsonEncode(materials);
}

/// Returns a JSON string that contains the direct resource location of desired object
/// with 'name' and 'link' keys
String parseResourceLink(String html, String linkType) {
  final doc = parse(html);

  String? extractedLink;

  print("\n\n\nLinktype: $linkType");

  for (final script in doc.querySelectorAll('script')) {
    final text = script.text;
    if (text.contains('FlexPaperViewer')) {
      final regex = RegExp(r"PDFFile\s*:\s*'([^']+)'");
      final match = regex.firstMatch(text);
      print("Match:  ${match?.group(1)}");
      if (match != null) {
        extractedLink = match.group(1);
        break;
      }
    }
  }

  // if (['resource', 'presentation', 'dyquestion', 'questionpaper']
  //     .contains(linkType)) {
  //   final main = doc.querySelector('[role="main"]');
  //   extractedLink = main?.querySelector('a')?.attributes['href'];
  // }

  if (extractedLink != null && extractedLink.isNotEmpty) {
    final start = extractedLink.lastIndexOf('/') + 1;
    final name = extractedLink.substring(start);
    final content = {
      'name': name,
      'link': extractedLink,
    };
    return jsonEncode(content);
  }

  return jsonEncode(null); // fallback if link is not found
}

// so annoying to write
// returns a jsonified timetable
String parseTimetable(String html) {
  print(html);
  final doc = parse(html);

  final output = <String, dynamic>{};
  final tdList = doc.querySelectorAll('td');

  // Extract class and semester (1st two divs in the first big <div>)
  final headerDivs = doc.querySelector('div')?.querySelectorAll('div') ?? [];
  if (headerDivs.length >= 2) {
    output['class'] = headerDivs[0].text.trim();
    output['semester'] = headerDivs[1].text.trim();
  } else {
    output['class'] = '';
    output['semester'] = '';
  }

  // Timeslot utility
  String getTime(int slot) {
    int hour = 9 + (slot - 1);
    if (hour > 12) hour -= 12;
    return '$hour:00';
  }

  // Subject handler (1 subject cell = 1 time slot)
  Map<String, String> handleSubject(Element td, int i) {
    final defaultReturn = {
      'subject': '',
      'room': '',
      'start': '',
      'end': '',
    };

    final items = td.querySelectorAll('li');
    if (items.length < 3) return defaultReturn;

    return {
      'subject': items[0].text.trim(),
      'room': items[2].text.trim(),
      'start': getTime(i),
      'end': getTime(i + 1),
    };
  }

  // Parsing 9 <td>s per row: 1st = Day Name, next 8 = subjects
  List<String> dayNames = [];
  Map<String, dynamic> timetable = {};
  List<Map<String, String>> currentDayData = [];

  for (int i = 0; i < tdList.length; i++) {
    final col = i % 9;
    final td = tdList[i];

    if (col == 0) {
      // New day starting
      if (currentDayData.isNotEmpty && dayNames.isNotEmpty) {
        timetable[dayNames.last] = {'data': currentDayData};
        currentDayData = [];
      }

      final dayName = td.text.trim();
      dayNames.add(dayName);
    } else {
      // Subject column
      final data = handleSubject(td, col);
      currentDayData.add(data);
    }
  }

  // Push last day’s data
  if (currentDayData.isNotEmpty && dayNames.isNotEmpty) {
    timetable[dayNames.last] = {'data': currentDayData};
  }

  output.addAll(timetable);
  return jsonEncode(output);
}

//json attendance summary
String parseAttendance(String html) {
  final doc = parse(html);
  final cells = doc.querySelectorAll('.cell');

  final result = <Map<String, String>>[];
  var entry = <String, String>{};
  final fields = ['subject', 'total', 'present', 'absent', 'percentage'];

  for (int i = 0; i < cells.length; i++) {
    final text = cells[i].text.trim() == '--' ? '0' : cells[i].text.trim();
    entry[fields[i % 5]] = text;

    if (i % 5 == 4) {
      result.add(entry);
      entry = {};
    }
  }

  return jsonEncode(result);
}
