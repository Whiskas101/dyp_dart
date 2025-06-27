import 'package:shelf_router/shelf_router.dart';
import 'package:dyp_dart/api/handlers/user_handler.dart';
// import 'package:dyp_dart/api/handlers/thing_handler.dart';

final appRoutes = Router()
  ..get('/subjects', getSubjects)
  ..post('/login', login)
  ..post('/materials', getMaterials)
  ..post('/download', getDownloadLink)
  ..get('/attendance', getAttendanceSummary);
