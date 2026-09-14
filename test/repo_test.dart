import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pausa_attiva/data/db/database.dart';
import 'package:pausa_attiva/data/repositories/break_repo.dart';
import 'package:pausa_attiva/data/repositories/settings_repo.dart';
import 'package:pausa_attiva/data/repositories/task_repo.dart';
import 'package:pausa_attiva/data/seed/builtin_breaks.dart';
import 'package:pausa_attiva/domain/enums.dart';
import 'package:pausa_attiva/domain/models.dart';

void main() {
  late AppDatabase db;
  late BreakRepo breaks;
  late TaskRepo tasks;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    breaks = BreakRepo(db);
    tasks = TaskRepo(db);
    await breaks.syncBuiltins();
  });

  tearDown(() => db.close());

  TaskTemplate task({List<String?> breakIds = const []}) => TaskTemplate(
        title: 'Scheda di matematica',
        timerMode: TimerMode.blocco,
        workSeconds: 300,
        blocksCount: 3,
        useBreaks: true,
        steps: const [
          TaskStep(label: 'Leggi', pictogram: PictogramRef.arasaac('100')),
          TaskStep(label: 'Scrivi', pictogram: PictogramRef.arasaac('200')),
        ],
        breakIds: breakIds,
      );

  test('pause di sistema caricate nell\'ordine del seed', () async {
    final all = await breaks.loadAll();
    expect(all.map((b) => b.id), builtinBreaks.map((b) => b.id));
    expect(all.last.moves, hasLength(3));
  });

  test('risincronizzare non duplica e non rompe le assegnazioni', () async {
    final id = await tasks.save(task(breakIds: ['spingi_i_palmi', null]));
    await breaks.syncBuiltins();
    await breaks.syncBuiltins();
    expect(await breaks.loadAll(), hasLength(14));
    final loaded = await tasks.load(id);
    expect(loaded!.breakIds, ['spingi_i_palmi', null]);
  });

  test('compito: salva, rileggi, modifica', () async {
    final id = await tasks.save(task(breakIds: ['marcia_sul_posto', 'respiro_quadrato']));
    var loaded = (await tasks.load(id))!;
    expect(loaded.steps.map((s) => s.label), ['Leggi', 'Scrivi']);
    expect(loaded.breakIds, ['marcia_sul_posto', 'respiro_quadrato']);

    await tasks.save(loaded.copyWith(
      title: 'Nuovo titolo',
      blocksCount: 2,
      steps: [loaded.steps.last],
    ));
    loaded = (await tasks.load(id))!;
    expect(loaded.title, 'Nuovo titolo');
    expect(loaded.steps, hasLength(1));
    expect(loaded.breakIds, ['marcia_sul_posto']);
  });

  test('le pause di sistema non si cancellano; le copie sì', () async {
    await breaks.delete('marcia_sul_posto');
    expect((await breaks.loadAll()).any((b) => b.id == 'marcia_sul_posto'),
        isTrue);

    final source = (await breaks.loadAll()).first;
    final copyId = await breaks.duplicate(source);
    var all = await breaks.loadAll();
    final copy = all.firstWhere((b) => b.id == copyId);
    expect(copy.isBuiltin, isFalse);
    expect(copy.copiedFrom, source.id);
    expect(all.last.id, copyId);

    await breaks.delete(copyId);
    all = await breaks.loadAll();
    expect(all.any((b) => b.id == copyId), isFalse);
  });

  test('cancellare una pausa assegnata lascia l\'intervallo vuoto', () async {
    final copyId = await breaks.duplicate((await breaks.loadAll()).first);
    final id = await tasks.save(task(breakIds: [copyId, 'spingi_i_palmi']));
    await breaks.delete(copyId);
    expect((await tasks.load(id))!.breakIds, [null, 'spingi_i_palmi']);
  });

  test('PIN: hash con sale, verifica', () {
    final stored = hashPin('1234');
    expect(stored, isNot(contains('1234')));
    expect(verifyPin('1234', stored), isTrue);
    expect(verifyPin('4321', stored), isFalse);
    expect(hashPin('1234'), isNot(stored), reason: 'sale diverso ogni volta');
  });
}
