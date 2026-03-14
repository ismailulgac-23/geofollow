import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CustomIcons {
  CustomIcons._();

  // Navigation Icons
  static const IconData home = FontAwesomeIcons.house;
  static const IconData map = FontAwesomeIcons.mapLocationDot;
  static const IconData places = FontAwesomeIcons.locationDot;
  static const IconData notifications = FontAwesomeIcons.bell;
  static const IconData profile = FontAwesomeIcons.user;

  // Social Login Icons
  static const IconData google = FontAwesomeIcons.google;
  static const IconData apple = FontAwesomeIcons.apple;
  static const IconData facebook = FontAwesomeIcons.facebookF;
  static const IconData twitter = FontAwesomeIcons.xTwitter;
  static const IconData instagram = FontAwesomeIcons.instagram;

  // Action Icons
  static const IconData message = FontAwesomeIcons.message;
  static const IconData call = FontAwesomeIcons.phone;
  static const IconData directions = FontAwesomeIcons.diamondTurnRight;
  static const IconData share = FontAwesomeIcons.shareNodes;
  static const IconData settings = FontAwesomeIcons.gear;
  static const IconData edit = FontAwesomeIcons.pen;
  static const IconData add = FontAwesomeIcons.plus;
  static const IconData remove = FontAwesomeIcons.minus;
  static const IconData close = FontAwesomeIcons.xmark;
  static const IconData check = FontAwesomeIcons.check;
  static const IconData search = FontAwesomeIcons.magnifyingGlass;
  static const IconData filter = FontAwesomeIcons.filter;

  // Status Icons
  static const IconData battery = FontAwesomeIcons.batteryFull;
  static const IconData batteryLow = FontAwesomeIcons.batteryQuarter;
  static const IconData wifi = FontAwesomeIcons.wifi;
  static const IconData noWifi = FontAwesomeIcons.circleXmark;
  static const IconData location = FontAwesomeIcons.locationCrosshairs;
  static const IconData ghost = FontAwesomeIcons.ghost;
  static const IconData shield = FontAwesomeIcons.shield;
  static const IconData lock = FontAwesomeIcons.lock;
  static const IconData unlock = FontAwesomeIcons.lockOpen;

  // Place Icons
  static const IconData homePlace = FontAwesomeIcons.house;
  static const IconData work = FontAwesomeIcons.briefcase;
  static const IconData school = FontAwesomeIcons.graduationCap;
  static const IconData gym = FontAwesomeIcons.dumbbell;
  static const IconData shop = FontAwesomeIcons.cartShopping;
  static const IconData restaurant = FontAwesomeIcons.utensils;
  static const IconData hospital = FontAwesomeIcons.hospital;
  static const IconData park = FontAwesomeIcons.tree;

  // Premium Icons
  static const IconData crown = FontAwesomeIcons.crown;
  static const IconData star = FontAwesomeIcons.star;
  static const IconData diamond = FontAwesomeIcons.gem;
  static const IconData sparkle = FontAwesomeIcons.wandMagicSparkles;
  static const IconData bolt = FontAwesomeIcons.bolt;

  // Misc Icons
  static const IconData chevronRight = FontAwesomeIcons.chevronRight;
  static const IconData chevronLeft = FontAwesomeIcons.chevronLeft;
  static const IconData chevronDown = FontAwesomeIcons.chevronDown;
  static const IconData chevronUp = FontAwesomeIcons.chevronUp;
  static const IconData arrowRight = FontAwesomeIcons.arrowRight;
  static const IconData arrowLeft = FontAwesomeIcons.arrowLeft;
  static const IconData circle = FontAwesomeIcons.circle;
  static const IconData circleCheck = FontAwesomeIcons.circleCheck;
  static const IconData info = FontAwesomeIcons.circleInfo;
  static const IconData warning = FontAwesomeIcons.triangleExclamation;
  static const IconData error = FontAwesomeIcons.circleExclamation;
  static const IconData success = FontAwesomeIcons.check;
}

class SocialLoginIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const SocialLoginIcon({
    super.key,
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 24,
  });

  factory SocialLoginIcon.google({VoidCallback? onTap, double size = 24}) {
    return SocialLoginIcon(
      icon: CustomIcons.google,
      color: const Color(0xFFEA4335),
      onTap: onTap,
      size: size,
    );
  }

  factory SocialLoginIcon.apple({VoidCallback? onTap, double size = 24}) {
    return SocialLoginIcon(
      icon: CustomIcons.apple,
      color: const Color(0xFF000000),
      onTap: onTap,
      size: size,
    );
  }

  factory SocialLoginIcon.facebook({VoidCallback? onTap, double size = 24}) {
    return SocialLoginIcon(
      icon: CustomIcons.facebook,
      color: const Color(0xFF1877F2),
      onTap: onTap,
      size: size,
    );
  }

  factory SocialLoginIcon.twitter({VoidCallback? onTap, double size = 24}) {
    return SocialLoginIcon(
      icon: CustomIcons.twitter,
      color: const Color(0xFF000000),
      onTap: onTap,
      size: size,
    );
  }

  factory SocialLoginIcon.instagram({VoidCallback? onTap, double size = 24}) {
    return SocialLoginIcon(
      icon: CustomIcons.instagram,
      color: const Color(0xFFE4405F),
      onTap: onTap,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }
}
