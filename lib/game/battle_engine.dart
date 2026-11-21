import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'word_kit.dart';

/// Word Battle: find words by chaining neighbouring letters before the
/// rival does. The rival's finds are planned when the level is generated,
/// so every round is deterministic and replayable.
class BattlePuzzle {
  final int size;
  final List<String> grid;

  /// Every dictionary word that can be traced in the grid (len >= 3).
  final List<String> words;

  /// (second, word) the rival finds.
  final List<(int, String)> rival;
  final int seconds;
  final String rivalName;
  const BattlePuzzle(this.size, this.grid, this.words, this.rival, this.seconds, this.rivalName);

  int get rivalScore => rival.fold(0, (a, b) => a + wordScore(b.$2));
  int get totalScore => words.fold(0, (a, b) => a + wordScore(b));
}

class BattleLevel {
  final Dual<BattlePuzzle> p;
  const BattleLevel(this.p);
}

int wordScore(String w) => switch (w.length) { <= 3 => 1, 4 => 2, 5 => 4, 6 => 6, _ => 10 };

List<int> neighbours(int i, int size) => [
      for (var dr = -1; dr <= 1; dr++)
        for (var dc = -1; dc <= 1; dc++)
          if (!(dr == 0 && dc == 0) &&
              i ~/ size + dr >= 0 &&
              i ~/ size + dr < size &&
              i % size + dc >= 0 &&
              i % size + dc < size)
            (i ~/ size + dr) * size + i % size + dc
    ];

List<String> findWords(List<String> grid, int size, WordLang lang) {
  final out = <String>{};
  void dfs(int i, String acc, Set<int> used) {
    final s = acc + grid[i];
    if (!lang.prefixes.contains(s)) return;
    if (s.length >= 3 && lang.dict.contains(s)) out.add(s);
    if (s.length >= 8) return;
    used.add(i);
    for (final n in neighbours(i, size)) {
      if (!used.contains(n)) dfs(n, s, used);
    }
    used.remove(i);
  }

  for (var i = 0; i < grid.length; i++) {
    dfs(i, '', <int>{});
  }
  return out.toList()..sort((a, b) => a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b));
}

const _rivals = ['Ada', 'Max', 'Lina', 'Kaan', 'Zoe', 'Emre', 'Nora', 'Leo', 'Defne', 'Sam'];

BattlePuzzle makeBattle(WordLang lang, SeededRandom r, int difficulty) {
  final size = difficulty >= 7 ? 5 : 4;
  final seconds = 90 + (size == 5 ? 30 : 0);
  final minWords = 10 + difficulty;
  List<String> grid = const [];
  List<String> words = const [];
  for (var t = 0; t < 30; t++) {
    grid = [
      for (var i = 0; i < size * size; i++)
        lang.randomLetter(r)
    ];
    final vowels = lang.letters.where(lang.isVowel).toList();
    for (var i = 0; i < grid.length; i += 3) {
      grid[i] = vowels[r.nextInt(vowels.length)];
    }
    words = findWords(grid, size, lang);
    if (words.length >= minWords) break;
  }
  final share = 0.16 + difficulty * 0.03;
  final total = words.fold(0, (a, b) => a + wordScore(b));
  final pool = [...words];
  r.shuffle(pool);
  final rival = <(int, String)>[];
  var score = 0;
  for (final w in pool) {
    if (score >= total * share) break;
    if (difficulty <= 3 && w.length > 5) continue;
    score += wordScore(w);
    rival.add((5 + r.nextInt(seconds - 10), w));
  }
  rival.sort((a, b) => a.$1.compareTo(b.$1));
  return BattlePuzzle(size, grid, words, rival, seconds, _rivals[r.nextInt(_rivals.length)]);
}

BattleLevel generateBattle(LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  return BattleLevel(Dual(makeBattle(WordLang.of(false), SeededRandom(r.nextUint32()), spec.difficulty),
      makeBattle(WordLang.of(true), SeededRandom(r.nextUint32()), spec.difficulty)));
}

String? checkBattle(BattlePuzzle p, WordLang lang) {
  if (p.words.length < 8) return 'few words';
  if (p.rival.isEmpty) return 'no rival';
  // The player must be able to beat the rival comfortably.
  if (p.totalScore < p.rivalScore * 2 + 2) return 'rival too strong';
  for (final (_, w) in p.rival) {
    if (!p.words.contains(w)) return 'rival word not in grid';
  }
  for (final w in p.words) {
    if (!lang.dict.contains(w)) return 'unknown $w';
  }
  return null;
}

class BattleGame {
  final BattlePuzzle p;
  final List<String> found = [];
  int elapsed = 0;
  int frozenUntil = 0;
  int freezeShift = 0;
  int mistakes = 0;
  BattleGame(this.p);

  int get score => found.fold(0, (a, b) => a + wordScore(b));

  List<String> get rivalFound => [
        for (final (t, w) in p.rival)
          if (t + freezeShift <= elapsed) w
      ];

  int get rivalScore => rivalFound.fold(0, (a, b) => a + wordScore(b));

  bool get over => elapsed >= p.seconds;
  bool get won => score > rivalScore;

  bool adjacentPath(List<int> path) {
    if (path.toSet().length != path.length) return false;
    for (var i = 1; i < path.length; i++) {
      if (!neighbours(path[i - 1], p.size).contains(path[i])) return false;
    }
    return true;
  }

  /// Returns the word if [path] traces a new valid word, otherwise null.
  String? submit(List<int> path) {
    if (path.length < 3 || !adjacentPath(path)) return null;
    final w = path.map((i) => p.grid[i]).join();
    if (!p.words.contains(w) || found.contains(w)) {
      if (!found.contains(w)) mistakes++;
      return null;
    }
    found.add(w);
    return w;
  }

  void tick(int seconds) => elapsed += seconds;

  /// Booster: the rival pauses for 15 seconds.
  void freeze() => freezeShift += 15;

  /// Hint: the path of the longest word not found yet.
  List<int>? hint() {
    final left = p.words.where((w) => !found.contains(w)).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final w in left) {
      final path = pathOf(w);
      if (path != null) return path;
    }
    return null;
  }

  List<int>? pathOf(String w) {
    List<int>? go(int i, int k, List<int> acc) {
      if (p.grid[i] != w[k] || acc.contains(i)) return null;
      final next = [...acc, i];
      if (k == w.length - 1) return next;
      for (final n in neighbours(i, p.size)) {
        final res = go(n, k + 1, next);
        if (res != null) return res;
      }
      return null;
    }

    for (var i = 0; i < p.grid.length; i++) {
      final res = go(i, 0, const []);
      if (res != null) return res;
    }
    return null;
  }

  String serialize() => [joinList(found), '$elapsed', '$freezeShift', '$mistakes'].join('|');

  factory BattleGame.restore(BattlePuzzle p, String s) {
    final g = BattleGame(p);
    final parts = s.split('|');
    if (parts.length < 4) return g;
    g.found.addAll(splitList(parts[0]).where(p.words.contains));
    g.elapsed = int.tryParse(parts[1]) ?? 0;
    g.freezeShift = int.tryParse(parts[2]) ?? 0;
    g.mistakes = int.tryParse(parts[3]) ?? 0;
    return g;
  }
}
