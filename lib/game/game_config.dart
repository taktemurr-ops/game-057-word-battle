import 'package:flutter/material.dart';

import '../app/game_api.dart';
import 'battle_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-057-word-battle',
  title: const ['Kelime Düellosu', 'Word Battle', 'Wortduell', 'Batalla de Palabras', 'Duel de Mots'],
  tagline: const ['Rakibinden daha çok kelime bul!', 'Find more words than your rival!', 'Finde mehr Wörter als dein Gegner!', '¡Encuentra más palabras que tu rival!', 'Trouvez plus de mots que l\'adversaire !'],
  seedColor: const Color(0xFFF72585),
  icon: Icons.sports_kabaddi,
  rules: BattleRules(),
  buildPlay: (ctx) => BattleView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.grid_view, ['Harfler yatay, dikey veya çapraz komşu olmalı.', 'Letters must touch (also diagonally).', 'Buchstaben müssen sich berühren.', 'Las letras deben tocarse.', 'Les lettres doivent se toucher.']),
    TutorialStep(Icons.smart_toy, ['Rakip de kelime buluyor; puan çubuğunu izle.', 'Your rival finds words too; watch the score bar.', 'Der Gegner sucht auch Wörter.', 'Tu rival también busca.', 'L\'adversaire cherche aussi.']),
    TutorialStep(Icons.ac_unit, ['Rakibi dondur: 15 saniye durur.', 'Freeze: the rival pauses for 15 seconds.', 'Einfrieren: 15 Sekunden Pause.', 'Congelar: 15 segundos.', 'Geler : 15 secondes.']),
  ],
);
