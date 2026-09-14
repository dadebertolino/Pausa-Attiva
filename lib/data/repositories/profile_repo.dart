import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../db/database.dart';

class ProfileRepo {
  ProfileRepo(this._db);

  final AppDatabase _db;

  Stream<List<Profile>> watchAll() => (_db.select(_db.profiles)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
      .watch()
      .map((rows) => [
            for (final r in rows)
              Profile(id: r.id, nickname: r.nickname, avatarId: r.avatarId),
          ]);

  Future<int> save(Profile profile) async {
    final companion = ProfilesCompanion(
      nickname: Value(profile.nickname),
      avatarId: Value(profile.avatarId),
    );
    if (profile.id == null) {
      return _db.into(_db.profiles).insert(companion);
    }
    await (_db.update(_db.profiles)..where((t) => t.id.equals(profile.id!)))
        .write(companion);
    return profile.id!;
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.profiles)..where((t) => t.id.equals(id))).go();
}
