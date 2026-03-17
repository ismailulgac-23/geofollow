import 'package:tracker_app/core/models/user_model.dart';
import 'package:tracker_app/core/models/place_model.dart';

class CircleModel {
  final String id;
  final String name;
  final String? emoji;
  final String? color;
  final String inviteCode;
  final List<UserModel> members;
  final List<PlaceModel>? places;
  final String? role;

  CircleModel({
    required this.id,
    required this.name,
    this.emoji,
    this.color,
    required this.inviteCode,
    required this.members,
    this.places,
    this.role,
  });

  factory CircleModel.fromJson(Map<String, dynamic> json) {
    return CircleModel(
      id: json['id'],
      name: json['name'],
      emoji: json['emoji'],
      color: json['color'],
      inviteCode: json['inviteCode'],
      role: json['role'],
      members: json['members'] != null
          ? (json['members'] as List).map((m) => UserModel.fromJson(m)).toList()
          : [],
      places: json['places'] != null
          ? (json['places'] as List).map((p) => PlaceModel.fromJson(p)).toList()
          : [],
    );
  }
  CircleModel copyWith({
    String? id,
    String? name,
    String? emoji,
    String? color,
    String? inviteCode,
    List<UserModel>? members,
    List<PlaceModel>? places,
    String? role,
  }) {
    return CircleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
      places: places ?? this.places,
      role: role ?? this.role,
    );
  }
}
