import '../core/game_rules.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'battle_engine.dart';
import 'word_kit.dart';

class BattleRules extends GameRules<BattleLevel> {
  @override
  String get gameId => 'game-057-word-battle';

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.endless, GameModeId.timeAttack, GameModeId.daily, GameModeId.weekly, GameModeId.challenge, GameModeId.zen];

  @override
  List<GameStat> get gameStats => const [
        GameStat('words_found', 'Bulunan kelime', 'Words found', scale: 150),
        GameStat('duels_won', 'Kazanılan düello', 'Duels won', scale: 10),
        GameStat('long_words', 'Uzun kelime (5+)', 'Long words (5+)', scale: 20),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('m1', 'words_found', [10, 25, 50]),
        MissionTemplate('m2', 'duels_won', [1, 3, 5], coinReward: 80),
      ];

  @override
  BattleLevel generate(LevelSpec spec) => generateBattle(spec);

  @override
  Validation validate(BattleLevel l, LevelSpec spec) {
    final e = checkBattle(l.p.en, WordLang.of(false)) ?? checkBattle(l.p.tr, WordLang.of(true));
    return e == null ? Validation.ok(l.p.en.words.length) : Validation.fail(e);
  }
}

GameRules createRules() => BattleRules();
