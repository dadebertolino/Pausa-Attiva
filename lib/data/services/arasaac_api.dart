import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../db/database.dart';

/// Risultato di ricerca ARASAAC (subset dello schema API rilevante).
class ArasaacPictogram {
  const ArasaacPictogram({
    required this.id,
    required this.keyword,
    required this.sex,
    required this.violence,
  });

  factory ArasaacPictogram.fromJson(Map<String, dynamic> json) {
    final keywords = (json['keywords'] as List<dynamic>?) ?? const [];
    final first = keywords.isNotEmpty
        ? (keywords.first as Map<String, dynamic>)['keyword'] as String? ?? ''
        : '';
    return ArasaacPictogram(
      id: json['_id'] as int,
      keyword: first,
      sex: json['sex'] as bool? ?? false,
      violence: json['violence'] as bool? ?? false,
    );
  }

  final int id;
  final String keyword;
  final bool sex;
  final bool violence;

  Map<String, dynamic> toJson() => {
        '_id': id,
        'keywords': [
          {'keyword': keyword},
        ],
        'sex': sex,
        'violence': violence,
      };
}

/// Client ARASAAC. La rete serve solo il catalogo pubblico, mai dati utente.
/// L'API serve per la ricerca; le immagini hanno URL statici deterministici.
class ArasaacApi {
  ArasaacApi(this._db, this._documentsDir, {http.Client? client})
      : _client = client ?? http.Client();

  static const _base = 'https://api.arasaac.org/v1';
  static const _static = 'https://static.arasaac.org/pictograms';
  static const _userAgent = 'PausaAttiva/${K.appVersion}';

  final AppDatabase _db;
  final Directory _documentsDir;
  final http.Client _client;

  /// Ricerca con FILTRO BAMBINI NON DISATTIVABILE (sex/violence).
  Future<List<ArasaacPictogram>> search(String text, {String lang = 'it'}) async {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final cached = await _readCache(query, lang);
    if (cached != null) return _childSafe(cached);

    final uri = Uri.parse(
        '$_base/pictograms/$lang/search/${Uri.encodeComponent(query)}');
    final res = await _client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 8));

    if (res.statusCode == 404) {
      await _writeCache(query, lang, const []);
      return const [];
    }
    if (res.statusCode != 200) {
      throw ArasaacException('HTTP ${res.statusCode} per "$query"');
    }

    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>)
        .map((j) => ArasaacPictogram.fromJson(j as Map<String, dynamic>))
        .toList();
    await _writeCache(query, lang, list);
    return _childSafe(list);
  }

  /// FILTRO OBBLIGATORIO: mai esporre pittogrammi sex/violence.
  static List<ArasaacPictogram> _childSafe(List<ArasaacPictogram> input) =>
      input.where((p) => !p.sex && !p.violence).toList();

  static String imageUrl(int id, {int res = K.resUi}) =>
      '$_static/$id/${id}_$res.png';

  /// File locale del pittogramma (può non esistere ancora).
  File localFile(int id, {int res = K.resUi}) =>
      File('${_documentsDir.path}/media/arasaac/${id}_$res.png');

  /// Scarica su disco se manca. Il compito deve funzionare senza rete (§7).
  Future<File> download(int id, {int res = K.resUi}) async {
    final file = localFile(id, res: res);
    if (await file.exists()) return file;

    final response = await _client
        .get(Uri.parse(imageUrl(id, res: res)),
            headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ArasaacException('Download fallito per pittogramma $id');
    }
    await file.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  /// Scarica tutti i pittogrammi indicati; restituisce quelli non riusciti.
  Future<List<int>> downloadAll(Iterable<int> ids) async {
    final failed = <int>[];
    for (final id in ids) {
      try {
        await download(id);
      } catch (_) {
        failed.add(id);
      }
    }
    return failed;
  }

  Future<List<ArasaacPictogram>?> _readCache(String query, String lang) async {
    final row = await (_db.select(_db.arasaacCache)
          ..where((t) => t.query.equals(query) & t.lang.equals(lang)))
        .getSingleOrNull();
    if (row == null) return null;
    if (DateTime.now().difference(row.fetchedAt) > K.arasaacCacheTtl) {
      return null;
    }
    return (jsonDecode(row.resultsJson) as List<dynamic>)
        .map((j) => ArasaacPictogram.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeCache(
    String query,
    String lang,
    List<ArasaacPictogram> results,
  ) =>
      _db.into(_db.arasaacCache).insertOnConflictUpdate(
            ArasaacCacheCompanion.insert(
              query: query,
              lang: lang,
              resultsJson: jsonEncode(results.map((p) => p.toJson()).toList()),
              fetchedAt: DateTime.now(),
            ),
          );
}

class ArasaacException implements Exception {
  ArasaacException(this.message);

  final String message;

  @override
  String toString() => 'ArasaacException: $message';
}

/// Attribuzione OBBLIGATORIA (CC BY-NC-SA) dove compaiono pittogrammi ARASAAC.
const arasaacAttribution = 'Pittogrammi: Sergio Palao / ARASAAC (arasaac.org), '
    'Governo di Aragona, licenza CC BY-NC-SA';
