import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'battle_engine.dart';
import 'rules.dart';
import 'word_ui.dart';

class BattleView extends StatefulWidget {
  final PlayContext ctx;
  const BattleView({super.key, required this.ctx});

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView> with RoundClock {
  late BattleLevel level;
  late BattleGame game;
  final List<int> path = [];
  List<int> _hintPath = const [];
  int _hints = 0;
  int _wins = 0;
  bool _ended = false;
  String _msg = '';
  bool _good = true;

  PlayContext get ctx => widget.ctx;
  bool get _tr => isTr(ctx);
  bool get _chain => ctx.spec.mode == GameModeId.endless;

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<BattleLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? BattleGame.restore(level.p.of(_tr), snap) : BattleGame(level.p.of(_tr));
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _wins = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    startClock(initialSeconds: game.elapsed, limit: ctx.spec.mode == GameModeId.zen ? 0 : game.p.seconds);
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _roundOver();

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'hints': _hints, 'solved': _wins});

  void _roundOver() {
    if (_ended) return;
    game.elapsed = game.p.seconds;
    final won = game.won;
    if (_chain && won) {
      _wins++;
      ctx.sfx(Sfx.combo);
      final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _wins]));
      setState(() {
        level = BattleRules().build(next).puzzle;
        game = BattleGame(level.p.of(_tr));
        path.clear();
      });
      startClock(limit: game.p.seconds);
      _persist();
      return;
    }
    _end(_chain ? _wins > 0 : won);
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    final margin = game.score - game.rivalScore;
    var stars = margin >= game.rivalScore ? 3 : (margin >= 4 ? 2 : 1);
    if (_chain) stars = _wins >= 4 ? 3 : (_wins >= 2 ? 2 : 1);
    ctx.finish(RoundResult(
      won: won,
      score: _chain ? _wins * 1000 + game.score * 10 : game.score * 50,
      stars: won ? stars : 0,
      seconds: game.elapsed,
      moves: game.found.length + game.mistakes,
      hintsUsed: _hints,
      gameStats: {
        'words_found': game.found.length,
        'duels_won': won ? 1 : 0,
        'long_words': game.found.where((w) => w.length >= 5).length,
      },
    ));
  }

  void _tap(int i) {
    if (_ended) return;
    setState(() {
      if (path.isNotEmpty && path.last == i) {
        path.removeLast();
      } else if (!path.contains(i) && (path.isEmpty || game.adjacentPath([path.last, i]))) {
        path.add(i);
      }
    });
    ctx.sfx(Sfx.tap);
  }

  void _submit() {
    final w = game.submit(path);
    setState(() {
      _msg = w == null ? tx(ctx, 'Not a word', 'Geçersiz') : '$w +${wordScore(w)}';
      _good = w != null;
      path.clear();
      _hintPath = const [];
    });
    ctx.sfx(w == null ? Sfx.error : Sfx.place);
    _persist();
    if (ctx.spec.mode == GameModeId.zen && game.found.length >= game.p.words.length ~/ 2) _end(true);
  }

  Future<void> _hint() async {
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => _hintPath = game.hint() ?? const []);
    _persist();
  }

  Future<void> _freeze() async {
    if (!await ctx.requestBooster()) return;
    setState(game.freeze);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    game.elapsed = math.max(game.elapsed, seconds);
    final word = path.map((i) => game.p.grid[i]).join();
    return WordBackdrop(
      colors: ctx.background,
      child: Column(children: [
        PlayHud(items: [
          (Icons.timer, timeText),
          (Icons.person, '${tx(ctx, 'You', 'Sen')} ${game.score}'),
          (Icons.smart_toy, '${game.p.rivalName} ${game.rivalScore}'),
          if (_chain) (Icons.emoji_events, '$_wins'),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(
            value: (game.score + game.rivalScore) == 0 ? 0.5 : game.score / (game.score + game.rivalScore),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        FeedbackLine(_msg, good: _good),
        SizedBox(height: 40, child: Center(child: Text(word, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final n = game.p.size;
            final side = math.min(c.maxWidth, c.maxHeight) - 16;
            final tile = side / n - 6;
            return Center(
              child: SizedBox(
                width: side,
                height: side,
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _PathPainter(path, n, side, cs.primary))),
                  GridView.count(
                    crossAxisCount: n,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < n * n; i++)
                        Center(
                          child: LetterTile(
                            game.p.grid[i],
                            size: tile,
                            color: path.contains(i)
                                ? cs.primary
                                : (_hintPath.isNotEmpty && _hintPath.first == i ? Colors.orange.shade300 : cs.primaryContainer),
                            textColor: path.contains(i) ? cs.onPrimary : cs.onPrimaryContainer,
                            onTap: () => _tap(i),
                          ),
                        ),
                    ],
                  ),
                ]),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${tx(ctx, 'Your words', 'Kelimelerin')}: ${game.found.join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton(onPressed: path.isEmpty ? null : () => setState(path.clear), child: Text(tx(ctx, 'Clear', 'Temizle'))),
          const SizedBox(width: 12),
          FilledButton(onPressed: path.length >= 3 ? _submit : null, child: Text(tx(ctx, 'Submit', 'Gönder'))),
        ]),
        BoosterBar(buttons: [
          BoosterButton(Icons.ac_unit, tx(ctx, 'Freeze rival', 'Rakibi dondur'), _freeze),
          BoosterButton(Icons.lightbulb, ctx.t('hint'), _hint),
        ]),
      ]),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<int> path;
  final int n;
  final double side;
  final Color color;
  _PathPainter(this.path, this.n, this.side, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final c = side / n;
    final p = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < path.length; i++) {
      final a = Offset((path[i - 1] % n + 0.5) * c, (path[i - 1] ~/ n + 0.5) * c);
      final b = Offset((path[i] % n + 0.5) * c, (path[i] ~/ n + 0.5) * c);
      canvas.drawLine(a, b, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
