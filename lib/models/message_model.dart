class MessageModel {
  final String id;
  final String text;
  final String type; // text, image, video, file, voice
  final String senderUid;
  final String senderName;
  final String senderPhoto;
  final int timestamp;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final String? duration; // for voice
  final Map<String, String> seenBy; // uid -> timestamp
  final bool delivered;

  MessageModel({
    required this.id,
    required this.text,
    required this.type,
    required this.senderUid,
    required this.senderName,
    this.senderPhoto = '',
    required this.timestamp,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.seenBy = const {},
    this.delivered = false,
  });

  factory MessageModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return MessageModel(
      id: id,
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      senderUid: map['senderUid'] ?? '',
      senderName: map['senderName'] ?? 'Cousin',
      senderPhoto: map['senderPhoto'] ?? '',
      timestamp: map['timestamp'] is int ? map['timestamp'] : 0,
      mediaUrl: map['mediaUrl'],
      fileName: map['fileName'],
      fileSize: map['fileSize'] is int ? map['fileSize'] : null,
      duration: map['duration'],
      seenBy: map['seenBy'] != null
          ? Map<String, String>.from(map['seenBy'] as Map)
          : {},
      delivered: map['delivered'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'type': type,
    'senderUid': senderUid,
    'senderName': senderName,
    'senderPhoto': senderPhoto,
    'timestamp': timestamp,
    if (mediaUrl != null) 'mediaUrl': mediaUrl,
    if (fileName != null) 'fileName': fileName,
    if (fileSize != null) 'fileSize': fileSize,
    if (duration != null) 'duration': duration,
    'seenBy': seenBy,
    'delivered': delivered,
  };
}
