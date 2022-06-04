import 'dart:io';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const serverUrl = 'otp.prod.sound.obaweb.org';

class OpenTripPlannerWrapper {
  static Future<Map<String, dynamic>> getItineraries(
      Map<String, dynamic> params) async {
    var uri = Uri.https(serverUrl, '/otp/routers/default/plan', params);
    print("uri: $uri");
    final jsonResponse = await http.get(uri);
    final body = json.decode(jsonResponse.body);
    final itineraries = body['plan'];
    return itineraries;
  }

  static Future<Database> openAndSetupDatabase() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(join(dbPath, 'otp3.db'));
    await db.execute(
        'CREATE TABLE IF NOT EXISTS queries (id INTEGER PRIMARY KEY, params TEXT, data TEXT, datetime TEXT)');
    return db;
  }

  static void saveQuery({
    required Map<String, dynamic> params,
    required Map<String, dynamic> data,
  }) async {
    final db = await openAndSetupDatabase();
    final last = await db
        .rawQuery("SELECT * FROM queries ORDER BY datetime DESC LIMIT 1");
    if (!last.isEmpty && last[0]['params'] != json.encode(params)) {
      //print(
      //    "otp:\nLast params: ${last[0]['params']}\nnew params: ${json.encode(params)}");
      await db.insert('queries', {
        'params': json.encode(params),
        'data': json.encode(data),
        'datetime': DateTime.now().toString()
      });
    }

    // insert params into queries table as json
  }

  static Future<List> getQueries() async {
    final db = await openAndSetupDatabase();
    final queries = await db
        .rawQuery("SELECT * FROM queries ORDER BY datetime DESC LIMIT 20");
    print(queries);
    return queries;
  }
}
