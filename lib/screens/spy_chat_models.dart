class SpyPlayerData {
  final String uid, name, photo;
  final String role;
  final bool alive, ready, confirmedWord;
  final int voteCount;

  SpyPlayerData({
    required this.uid,
    required this.name,
    required this.photo,
    this.role = 'civilian',
    this.alive = true,
    this.ready = false,
    this.confirmedWord = false,
    this.voteCount = 0,
  });

  factory SpyPlayerData.fromMap(Map<String, dynamic> map, String uid) {
    return SpyPlayerData(
      uid: uid,
      name: map['name'] as String? ?? 'Cousin',
      photo: map['photo'] as String? ?? '',
      role: map['role'] as String? ?? 'civilian',
      alive: map['alive'] as bool? ?? true,
      ready: map['isReady'] as bool? ?? false,
      confirmedWord: map['confirmedWord'] as bool? ?? false,
    );
  }
}

const int kMinPlayers = 5;
const int kMaxPlayers = 15;
const int kDiscussionTimerSec = 90;
const int kVotingTimerSec = 30;

int spyCount(int total) {
  if (total <= 6) return 1;
  if (total <= 10) return 2;
  return 3;
}
