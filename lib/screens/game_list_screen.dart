import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'ludo_king_invite_screen.dart';
import 'tictactoe_invite_screen.dart';
import 'pass_the_bomb_lobby_screen.dart';
import 'pass_the_card_lobby_screen.dart';
import 'truth_or_dare_lobby_screen.dart';
import 'spy_chat_lobby_screen.dart';
import 'rps_lobby_screen.dart';
import 'charades_lobby_screen.dart';

class GameListScreen extends StatelessWidget {
  const GameListScreen({super.key});

  static const _games = [
    _GameData('🎲', 'Ludo King', Colors.deepPurple, LudoKingInviteScreen.new),
    _GameData('🎭', 'Truth or Dare', Color(0xFF2D1B69), TruthOrDareLobbyScreen.new),
    _GameData('🃏', 'Pass The Card', Color(0xFF1B3A1B), PassTheCardLobbyScreen.new),
    _GameData('💣', 'Pass The Bomb', Color(0xFF4A0E4E), PassTheBombLobbyScreen.new),
    _GameData('❌', 'Tic Tac Toe', Color(0xFF1B3A2D), TicTacToeInviteScreen.new),
    _GameData('🕵️', 'Spy Chat', Color(0xFF2D1B4E), SpyChatLobbyScreen.new),
    _GameData('🪨📄✂️', 'RPS', Color(0xFF1A3A5C), RpsLobbyScreen.new),
    _GameData('🎭', 'Charades', Color(0xFF5C2D1A), CharadesLobbyScreen.new),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
          onPressed: () => Navigator.pop(context)),
        title: const Text('All Games 🎮',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.ink))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _games.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final g = _games[i];
          return _GameCard(
            emoji: g.emoji, name: g.name, color: g.color,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => g.screen())),
          );
        },
      ),
    );
  }
}

class _GameData {
  final String emoji, name;
  final Color color;
  final Widget Function() screen;
  const _GameData(this.emoji, this.name, this.color, this.screen);
}

class _GameCard extends StatelessWidget {
  final String emoji, name;
  final Color color;
  final VoidCallback? onTap;

  const _GameCard({
    required this.emoji, required this.name,
    required this.color, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(child: Text(name,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: onTap != null ? AppTheme.ink : Colors.grey)),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppTheme.ink, size: 22),
        ]),
      ),
    );
  }
}
