import 'package:flutter/material.dart';

class CardType {
  final int id;
  final String label;
  final Color color;
  final String? assetPath;

  const CardType({
    required this.id,
    required this.label,
    required this.color,
    this.assetPath,
  });
}

const List<CardType> kCardTypes = [
  CardType(id: 0, label: '\u{1F431}', color: Color(0xFFE74C3C)),
  CardType(id: 1, label: '\u{1F436}', color: Color(0xFF3498DB)),
  CardType(id: 2, label: '\u{1F602}', color: Color(0xFF2ECC71)),
  CardType(id: 3, label: '\u{1F438}', color: Color(0xFFF1C40F)),
];

const int kCardsPerType = 4;
const int kTotalCards = 16;
const int kHandSize = 4;
const int kPlayersCount = 4;
const int kSelectionTimeSec = 15;
const int kTurnTimeSec = 10;

CardType cardTypeById(int id) => kCardTypes.firstWhere((ct) => ct.id == id);

class PlayerCardData {
  final String uid, name, photo;
  final int position;
  final int cardCount;

  PlayerCardData({
    required this.uid,
    required this.name,
    required this.photo,
    this.position = 0,
    this.cardCount = 4,
  });

  factory PlayerCardData.fromMap(Map<String, dynamic> map, String uid) {
    final hand = map['hand'] as List<dynamic>?;
    return PlayerCardData(
      uid: uid,
      name: map['name'] as String? ?? 'Cousin',
      photo: map['photo'] as String? ?? '',
      position: map['position'] as int? ?? 0,
      cardCount: hand?.length ?? 4,
    );
  }
}
