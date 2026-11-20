import 'package:flutter_test/flutter_test.dart';
import 'package:game_057_word_battle/core/level_plan.dart';
import 'package:game_057_word_battle/game/battle_engine.dart';
import 'package:game_057_word_battle/game/rules.dart';
import 'package:game_057_word_battle/game/word_kit.dart';

void main() {
  final rules = BattleRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('grids hold enough words and a beatable rival, both languages', () {
    for (final n in [1, 6, 66, 700, 7000, 49999]) {
      final l = rules.build(planner.spec(n)).puzzle;
      for (final tr in [false, true]) {
        expect(checkBattle(l.p.of(tr), WordLang.of(tr)), isNull, reason: 'level $n tr=$tr');
      }
    }
  });

  test('a player that traces every word beats the rival', () {
    for (final n in [1, 40, 900]) {
      final p = rules.build(planner.spec(n)).puzzle.p.en;
      final g = BattleGame(p);
      for (final w in p.words) {
        final path = g.pathOf(w)!;
        expect(g.submit(path), w);
      }
      g.tick(p.seconds);
      expect(g.over, isTrue);
      expect(g.won, isTrue, reason: 'level $n');
    }
  });

  test('invalid paths are rejected, rival scores over time, freeze delays it', () {
    final p = rules.build(planner.spec(10)).puzzle.p.tr;
    final g = BattleGame(p);
    expect(g.submit([0, 0, 1]), isNull);
    expect(g.rivalScore, 0);
    g.tick(p.seconds);
    expect(g.rivalScore, p.rivalScore);
    final h = BattleGame(p)..freeze();
    h.tick(p.rival.first.$1);
    expect(h.rivalFound, isEmpty);
    expect(BattleGame.restore(p, g.serialize()).serialize(), g.serialize());
  });

  test('levels 1..40 valid', () {
    for (var n = 1; n <= 40; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
