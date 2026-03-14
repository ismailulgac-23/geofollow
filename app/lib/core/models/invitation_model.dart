import 'package:google_maps_flutter/google_maps_flutter.dart';

class InvitationModel {
  final String id;
  final String circleId;
  final String circleName;
  final String circleDescription;
  final String invitedByName;
  final String invitedByAvatar;
  final String invitedAt;
  final int memberCount;
  final LatLng centerLocation;
  final String status; // 'pending', 'accepted', 'declined'

  const InvitationModel({
    required this.id,
    required this.circleId,
    required this.circleName,
    required this.circleDescription,
    required this.invitedByName,
    required this.invitedByAvatar,
    required this.invitedAt,
    required this.memberCount,
    required this.centerLocation,
    this.status = 'pending',
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      id: json['id'] ?? '',
      circleId: json['circleId'] ?? '',
      circleName: json['circleName'] ?? '',
      circleDescription: json['circleDescription'] ?? '',
      invitedByName: json['invitedByName'] ?? '',
      invitedByAvatar: json['invitedByAvatar'] ?? '',
      invitedAt: json['invitedAt'] ?? '',
      memberCount: json['memberCount'] ?? 0,
      centerLocation: json['centerLocation'] ?? const LatLng(41.0082, 28.9784),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'circleId': circleId,
      'circleName': circleName,
      'circleDescription': circleDescription,
      'invitedByName': invitedByName,
      'invitedByAvatar': invitedByAvatar,
      'invitedAt': invitedAt,
      'memberCount': memberCount,
      'centerLocation': centerLocation,
      'status': status,
    };
  }

  InvitationModel copyWith({
    String? id,
    String? circleId,
    String? circleName,
    String? circleDescription,
    String? invitedByName,
    String? invitedByAvatar,
    String? invitedAt,
    int? memberCount,
    LatLng? centerLocation,
    String? status,
  }) {
    return InvitationModel(
      id: id ?? this.id,
      circleId: circleId ?? this.circleId,
      circleName: circleName ?? this.circleName,
      circleDescription: circleDescription ?? this.circleDescription,
      invitedByName: invitedByName ?? this.invitedByName,
      invitedByAvatar: invitedByAvatar ?? this.invitedByAvatar,
      invitedAt: invitedAt ?? this.invitedAt,
      memberCount: memberCount ?? this.memberCount,
      centerLocation: centerLocation ?? this.centerLocation,
      status: status ?? this.status,
    );
  }
}