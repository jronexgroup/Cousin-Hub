class PlayerData {
  final String uid, name, photo;
  final bool online, isReady;
  PlayerData({required this.uid, required this.name, required this.photo,
    this.online = true, this.isReady = false});
}
