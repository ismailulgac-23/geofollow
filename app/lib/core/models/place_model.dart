import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tracker_app/l10n/app_localizations.dart';

class PlaceModel {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final double radius;
  final String emoji;
  final List<String> memberIds;
  final bool isActive;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.radius,
    required this.emoji,
    this.memberIds = const [],
    this.isActive = true,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      location: LatLng(
        (json['latitude'] ?? 41.0082).toDouble(),
        (json['longitude'] ?? 28.9784).toDouble(),
      ),
      radius: (json['radius'] ?? 150).toDouble(),
      emoji: json['emoji'] ?? '📍',
      memberIds: json['memberIds'] != null
          ? List<String>.from(json['memberIds'])
          : [],
      isActive: json['isActive'] ?? true,
    );
  }

  factory PlaceModel.mock(String id, String name, String emoji) {
    final locations = <LatLng>[
      const LatLng(41.0082, 28.9784),
      const LatLng(41.0124, 28.9856),
      const LatLng(41.0056, 28.9721),
      const LatLng(41.0189, 28.9667),
      const LatLng(40.9921, 28.9901),
    ];
    final addresses = [
      'Levent Mah. Istanbul',
      'Maslak Mah. Istanbul',
      'Besiktas Mah. Istanbul',
      'Kadikoy Mah. Istanbul',
      'Sisli Mah. Istanbul',
    ];
    final index = int.parse(id.replaceAll('place_', '')) % 5;

    return PlaceModel(
      id: id,
      name: name,
      address: addresses[index],
      location: locations[index],
      radius: [150.0, 200.0, 100.0, 300.0, 250.0][index],
      emoji: emoji,
      memberIds: ['user_1', 'user_2'],
      isActive: true,
    );
  }

  PlaceModel copyWith({
    String? id,
    String? name,
    String? address,
    LatLng? location,
    double? radius,
    String? emoji,
    List<String>? memberIds,
    bool? isActive,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      emoji: emoji ?? this.emoji,
      memberIds: memberIds ?? this.memberIds,
      isActive: isActive ?? this.isActive,
    );
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool isRead;
  final String? avatarUrl;
  final String? userId;
  final String? userName;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.avatarUrl,
    this.userId,
    this.userName,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      timestamp: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      avatarUrl: json['avatarUrl'],
      userId: json['userId'],
      userName: json['userName'] ?? 'Member',
    );
  }

  factory NotificationModel.mock(String id, int index) {
    final notifications = [
      (
        'Low Battery',
        'Mom\'s battery is below 10%',
        'battery_low',
        'https://i.pravatar.cc/150?u=mom',
        'Mom',
      ),
      (
        'Arrived',
        'Sarah arrived at Home',
        'arrival',
        'https://i.pravatar.cc/150?u=sarah',
        'Sarah',
      ),
      (
        'Left Location',
        'Dad left Office',
        'departure',
        'https://i.pravatar.cc/150?u=dad',
        'Dad',
      ),
      (
        'SOS Alert',
        'John triggered an SOS alert',
        'sos',
        'https://i.pravatar.cc/150?u=john',
        'John',
      ),
      (
        'Speed Alert',
        'Emma exceeded speed limit',
        'speed',
        'https://i.pravatar.cc/150?u=emma',
        'Emma',
      ),
      (
        'New Member',
        'Alice joined your circle',
        'member',
        'https://i.pravatar.cc/150?u=alice',
        'Alice',
      ),
    ];

    final data = notifications[index % notifications.length];
    final now = DateTime.now();

    return NotificationModel(
      id: id,
      title: data.$1,
      message: data.$2,
      type: data.$3,
      timestamp: now.subtract(Duration(hours: index * 2, minutes: index * 15)),
      isRead: index > 2,
      avatarUrl: data.$4,
      userId: 'user_${index + 1}',
      userName: data.$5,
    );
  }

  String get icon {
    switch (type) {
      case 'battery':
        return '🔋';
      case 'arrival':
        return '📍';
      case 'departure':
        return '🚗';
      case 'sos':
        return '🆘';
      case 'speed':
        return '⚡';
      case 'member':
        return '👋';
      case 'place_entered':
        return '📍';
      case 'place_exited':
        return '🚶';
      case 'movement_started':
        return '🏃';
      default:
        return '🔔';
    }
  }

  String getTimeAgo(AppLocalizations l10n) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    return l10n.daysAgo(diff.inDays);
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    String? avatarUrl,
    String? userId,
    String? userName,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
    );
  }
}
