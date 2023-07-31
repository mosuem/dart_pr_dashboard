import 'dart:convert';

import 'package:dart_triage_updater/update_type.dart';
import 'package:github/github.dart';
import 'package:http/http.dart' as http;

final firebaseUrl =
    'https://dart-pr-dashboard-default-rtdb.europe-west1.firebasedatabase.app/';

class DatabaseReference {
  final UpdateType type;

  DatabaseReference(this.type);

  Future<void> addData(String data, String dataType) async {
    final uri = Uri.parse('$firebaseUrl${type.name}/$dataType.json');
    final response = await http.patch(uri, body: data);
    if (response.statusCode != 200) {
      throw Exception('Error adding data $data in $type: ${response.body}');
    }
  }

  static Future<void> saveGooglers(List googlers) async {
    final uri = Uri.parse('$firebaseUrl.json');
    final response =
        await http.patch(uri, body: jsonEncode({'googlers': googlers}));
    if (response.statusCode != 200) {
      throw Exception('Error adding Googlers ${response.body}');
    }
  }

  static Future<void> setLastUpdated(RepositorySlug slug) async {
    final uri = Uri.parse('${firebaseUrl}last_updated.json');
    final lastUpdated =
        DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch;
    final response =
        await http.patch(uri, body: jsonEncode({slug.toUrl(): lastUpdated}));
    if (response.statusCode != 200) {
      throw Exception('Error adding Googlers ${response.body}');
    }
  }

  static Future<Map<RepositorySlug, DateTime?>> getLastUpdated() async {
    final uri = Uri.parse('${firebaseUrl}last_updated.json');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Error adding Googlers ${response.body}');
    }
    final map = (jsonDecode(response.body) ?? <String, dynamic>{})
        as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(
        RepositorySlugExtension.fromUrl(key),
        DateTime.fromMillisecondsSinceEpoch(value)));
  }

  static List<T> extractDataFrom<T>(
    Map<String, dynamic> idsToData,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final list = <T>[];
    for (final idToData in idsToData.entries) {
      // ignore: unused_local_variable
      final id = idToData.key;
      final data = fromJson(idToData.value);
      list.add(data);
    }
    return list;
  }
}

extension RepositorySlugExtension on RepositorySlug {
  String toUrl() {
    final ownerClean = owner.replaceAll(r'.', r',');
    final nameClean = name.replaceAll(r'.', r',');
    return '$ownerClean:$nameClean';
  }

  static RepositorySlug fromUrl(String url) {
    final split = url.split(':');
    final owner = split[0];
    final name = split[1];
    return RepositorySlug(
        owner.replaceAll(r',', r'.'), name.replaceAll(r',', r'.'));
  }
}
