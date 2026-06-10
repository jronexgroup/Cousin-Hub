class PlayerData {
  final String uid, name, photo;
  final bool alive;
  final int? eliminationOrder;
  PlayerData({required this.uid, required this.name, required this.photo,
    this.alive = true, this.eliminationOrder});
}
