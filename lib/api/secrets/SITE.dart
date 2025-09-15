const String _baseHost = 'mydy.dypatil.edu';

final Uri AUTH_URL = Uri.https(_baseHost, '/rait/login/index.php');

final Uri SUBJECTS_URL = Uri.https(
  _baseHost,
  '/rait/blocks/academic_status/ajax.php',
  {'action': 'myclasses'},
);

final Uri ATTENDANCE_URL = Uri.https(
  _baseHost,
  '/rait/blocks/academic_status/ajax.php',
  {'action': 'attendance'},
);

final Uri TIMETABLE_URL = Uri.https(
  _baseHost,
  '/rait/blocks/academic_status/ajax.php',
  {'action': 'timetable'},
);
