import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracker_app/l10n/app_localizations.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String avatarUrl;
  final String status;
  final int batteryLevel;
  final DateTime lastUpdated;
  final LatLng location;
  final String address;
  final bool isOnline;
  final String? statusEmoji;
  final bool isPremium;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.status,
    required this.batteryLevel,
    required this.lastUpdated,
    required this.location,
    required this.address,
    this.isOnline = true,
    this.statusEmoji,
    this.isPremium = false,
  });

  factory UserModel.empty() {
    return UserModel(
      id: '',
      email: '',
      name: '',
      avatarUrl: '',
      status: '',
      batteryLevel: 0,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
      location: const LatLng(0, 0),
      address: '',
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      status: json['status'] ?? 'Online',
      statusEmoji: json['statusEmoji'],
      batteryLevel: json['batteryLevel'] ?? 100,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
      location: LatLng(
        (json['latitude'] ?? 41.0082).toDouble(),
        (json['longitude'] ?? 28.9784).toDouble(),
      ),
      address: json['address'] ?? 'Unknown Address',
      isOnline: json['isOnline'] ?? true,
      isPremium: json['isPremium'] ?? false,
    );
  }

  factory UserModel.mock(String id, String name, String avatarSuffix) {
    final locations = <LatLng>[
      const LatLng(41.0082, 28.9784),
      const LatLng(41.0124, 28.9856),
      const LatLng(41.0056, 28.9721),
      const LatLng(41.0189, 28.9667),
      const LatLng(40.9921, 28.9901),
    ];
    final addresses = [
      'Levent, Istanbul',
      'Besiktas, Istanbul',
      'Sisli, Istanbul',
      'Kadikoy, Istanbul',
      'Uskudar, Istanbul',
    ];
    final statuses = [
      ('At Home', '🏠'),
      ('At Work', '💼'),
      ('Driving', '🚗'),
      ('At Gym', '💪'),
      ('Shopping', '🛒'),
    ];

    final index = int.parse(id.replaceAll('user_', '')) % 5;
    final statusData = statuses[index];
    final battery = [85, 92, 15, 45, 67][index];

    return UserModel(
      id: id,
      email: '${name.toLowerCase().replaceAll(' ', '.')}@example.com',
      name: name,
      avatarUrl: 'https://i.pravatar.cc/150?u=$avatarSuffix',
      status: statusData.$1,
      statusEmoji: statusData.$2,
      batteryLevel: battery,
      lastUpdated: DateTime.now().subtract(Duration(minutes: index * 5 + 2)),
      location: locations[index],
      address: addresses[index],
      isOnline: index != 2,
    );
  }

  String getTimeAgo(AppLocalizations l10n) {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    return l10n.daysAgo(diff.inDays);
  }

  String get batteryIcon {
    if (batteryLevel <= 10) return '🔋';
    if (batteryLevel <= 20) return '🪫';
    return '🔋';
  }

  bool get isLowBattery => batteryLevel <= 20;

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? status,
    int? batteryLevel,
    DateTime? lastUpdated,
    LatLng? location,
    String? address,
    bool? isOnline,
    String? statusEmoji,
    bool? isPremium,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      location: location ?? this.location,
      address: address ?? this.address,
      isOnline: isOnline ?? this.isOnline,
      statusEmoji: statusEmoji ?? this.statusEmoji,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}

// ─── MovementHistory ────────────────────────────────────────────────────────

class MovementHistory {
  final String id;
  final String userId;
  final String placeName;
  final LatLng location;
  final DateTime arrivedAt;
  final DateTime? leftAt;
  final String address;
  final String emoji;
  final int visitCount;
  final int? durationMins;

  const MovementHistory({
    required this.id,
    required this.userId,
    required this.placeName,
    required this.location,
    required this.arrivedAt,
    this.leftAt,
    required this.address,
    this.emoji = '📍',
    this.visitCount = 1,
    this.durationMins,
  });

  factory MovementHistory.fromJson(Map<String, dynamic> json) {
    return MovementHistory(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      placeName: json['placeName'] ?? '',
      location: LatLng(
        (json['latitude'] ?? 0.0).toDouble(),
        (json['longitude'] ?? 0.0).toDouble(),
      ),
      address: json['address'] ?? '',
      emoji: json['emoji'] ?? '📍',
      arrivedAt: json['arrivedAt'] != null
          ? DateTime.parse(json['arrivedAt'])
          : DateTime.now(),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
      visitCount: json['visitCount'] ?? 1,
      durationMins: json['durationMins'],
    );
  }

  factory MovementHistory.mock(String id, String userId, int index) {
    final places = ['Home', 'Office', 'Gym', 'Coffee Shop', 'Supermarket'];
    final emojis = ['🏠', '💼', '💪', '☕', '🛒'];
    final addresses = [
      'Levent Mah. Istanbul',
      'Maslak Mah. Istanbul',
      'Besiktas Mah. Istanbul',
      'Kadikoy Mah. Istanbul',
      'Sisli Mah. Istanbul',
    ];
    final locations = <LatLng>[
      const LatLng(41.0082, 28.9784),
      const LatLng(41.0124, 28.9856),
      const LatLng(41.0056, 28.9721),
      const LatLng(41.0189, 28.9667),
      const LatLng(40.9921, 28.9901),
    ];

    final now = DateTime.now();
    final hourOffset = index * 3;

    return MovementHistory(
      id: id,
      userId: userId,
      placeName: places[index % 5],
      emoji: emojis[index % 5],
      location: locations[index % 5],
      address: addresses[index % 5],
      arrivedAt: now.subtract(Duration(hours: hourOffset + 2)),
      leftAt: index < 3 ? now.subtract(Duration(hours: hourOffset)) : null,
      visitCount: (index + 1) * 3,
      durationMins: index < 3 ? (hourOffset * 60) : null,
    );
  }

  String getTimeRange(AppLocalizations l10n) {
    final h = arrivedAt.hour.toString().padLeft(2, '0');
    final m = arrivedAt.minute.toString().padLeft(2, '0');
    final arrivedStr = '$h:$m';
    if (leftAt == null) return '$arrivedStr - ${l10n.now}';
    final lh = leftAt!.hour.toString().padLeft(2, '0');
    final lm = leftAt!.minute.toString().padLeft(2, '0');
    return '$arrivedStr - $lh:$lm';
  }

  String get duration {
    final end = leftAt ?? DateTime.now();
    final diff = end.difference(arrivedAt);
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes}m';
  }
}

// ─── FrequentPlace ──────────────────────────────────────────────────────────

/// Sık gidilen yerlerin istatistiksel özeti
class FrequentPlace {
  final String placeId;
  final String placeName;
  final String address;
  final String emoji;
  final LatLng location;
  final int totalVisits;
  final int totalMinutes;
  final DateTime? lastVisit;

  const FrequentPlace({
    required this.placeId,
    required this.placeName,
    required this.address,
    required this.emoji,
    required this.location,
    required this.totalVisits,
    required this.totalMinutes,
    this.lastVisit,
  });

  factory FrequentPlace.fromJson(Map<String, dynamic> json) {
    return FrequentPlace(
      placeId: json['placeId'] ?? '',
      placeName: json['placeName'] ?? '',
      address: json['address'] ?? '',
      emoji: json['emoji'] ?? '📍',
      location: LatLng(
        (json['latitude'] ?? 0.0).toDouble(),
        (json['longitude'] ?? 0.0).toDouble(),
      ),
      totalVisits: json['totalVisits'] ?? 0,
      totalMinutes: json['totalMinutes'] ?? 0,
      lastVisit: json['lastVisit'] != null
          ? DateTime.parse(json['lastVisit'])
          : null,
    );
  }

  String get avgDuration {
    if (totalVisits == 0) return '0m';
    final avg = totalMinutes ~/ totalVisits;
    if (avg >= 60) return '${avg ~/ 60}h ${avg % 60}m';
    return '${avg}m';
  }
}
