int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Satu peserta di dalam room Belajar Bareng.
class RoomPlayer {
  const RoomPlayer({
    required this.userId,
    required this.name,
    required this.isHost,
    required this.isMe,
    required this.submitted,
    this.score,
    this.correct,
    this.wrong,
    this.rank,
  });

  final int userId;
  final String name;
  final bool isHost;
  final bool isMe;
  final bool submitted;

  /// Skor, benar, salah, dan peringkat baru terisi setelah room selesai.
  final int? score;
  final int? correct;
  final int? wrong;
  final int? rank;

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      userId: _asInt(json['userId']) ?? 0,
      name: (json['name'] ?? 'Siswa').toString(),
      isHost: json['isHost'] == true,
      isMe: json['isMe'] == true,
      submitted: json['submitted'] == true,
      score: _asInt(json['score']),
      correct: _asInt(json['correct']),
      wrong: _asInt(json['wrong']),
      rank: _asInt(json['rank']),
    );
  }
}

/// Keadaan room terbaru dari server.
class RoomState {
  const RoomState({
    required this.code,
    required this.subtestId,
    required this.questionCount,
    required this.durationSeconds,
    required this.status,
    required this.startedAt,
    required this.endsAt,
    required this.serverNow,
    required this.players,
  });

  final String code;
  final String subtestId;
  final int questionCount;
  final int durationSeconds;

  /// 'waiting' | 'running' | 'finished' | 'closed'
  final String status;

  /// Milidetik epoch (waktu server). Null jika belum dimulai.
  final int? startedAt;
  final int? endsAt;
  final int serverNow;
  final List<RoomPlayer> players;

  bool get isWaiting => status == 'waiting';
  bool get isRunning => status == 'running';
  bool get isFinished => status == 'finished';
  bool get isClosed => status == 'closed';

  RoomPlayer? get me {
    for (final p in players) {
      if (p.isMe) return p;
    }
    return null;
  }

  bool get iAmHost => me?.isHost ?? false;

  int get submittedCount => players.where((p) => p.submitted).length;

  factory RoomState.fromJson(Map<String, dynamic> json) {
    final room =
        (json['room'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final players = (json['players'] as List?) ?? const [];

    return RoomState(
      code: (room['code'] ?? '').toString(),
      subtestId: (room['subtestId'] ?? '').toString(),
      questionCount: _asInt(room['questionCount']) ?? 0,
      durationSeconds: _asInt(room['durationSeconds']) ?? 0,
      status: (room['status'] ?? 'waiting').toString(),
      startedAt: _asInt(room['startedAt']),
      endsAt: _asInt(room['endsAt']),
      serverNow:
          _asInt(room['serverNow']) ?? DateTime.now().millisecondsSinceEpoch,
      players: players
          .whereType<Map>()
          .map((m) => RoomPlayer.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }

  RoomState copyWithStatus(String newStatus) {
    return RoomState(
      code: code,
      subtestId: subtestId,
      questionCount: questionCount,
      durationSeconds: durationSeconds,
      status: newStatus,
      startedAt: startedAt,
      endsAt: endsAt,
      serverNow: serverNow,
      players: players,
    );
  }
}
