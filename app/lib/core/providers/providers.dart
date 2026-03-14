import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/core/services/notification_service.dart';
import 'package:tracker_app/core/services/api_client.dart';
import 'package:tracker_app/core/providers/circle_provider.dart';
import 'package:tracker_app/core/models/place_model.dart';
import 'package:tracker_app/core/models/user_model.dart';
export 'package:tracker_app/core/providers/toast_provider.dart';
export 'package:tracker_app/core/providers/circle_provider.dart';
export 'package:tracker_app/core/providers/auth_provider.dart';

// Users Provider derived from Circle
final usersProvider = Provider<List<UserModel>>((ref) {
  final circleState = ref.watch(circleProvider);
  if (circleState.circle != null) {
    return circleState.circle!.members;
  }
  return [];
});

// Selected User Provider
final selectedUserProvider = StateProvider<UserModel?>((ref) => null);

// Places Provider derived from Circle
final placesProvider = Provider<List<PlaceModel>>((ref) {
  final circleState = ref.watch(circleProvider);
  if (circleState.circle != null && circleState.circle!.places != null) {
    return circleState.circle!.places!;
  }
  return [];
});

// Notifications Notifier
class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier() : super([]) {
    fetchNotifications();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    NotificationService.onNotificationReceived.listen((message) {
      fetchNotifications();
    });
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await ApiClient.getNotifications();
      if (response['success'] == true) {
        final List<dynamic> data = response['data']['notifications'];
        state = data.map((n) => NotificationModel.fromJson(n)).toList();
      }
    } catch (e) {
      // print('Failed to fetch notifications: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await ApiClient.markNotificationAsRead(id);
      state = state.map((n) {
        if (n.id == id) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
    } catch (e) {
      //
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiClient.markAllNotificationsAsRead();
      state = state.map((n) => n.copyWith(isRead: true)).toList();
    } catch (e) {
      //
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>((
      ref,
    ) {
      return NotificationsNotifier();
    });

// Movement History Notifier — gerçek API'den veri çeker
class MovementHistoryNotifier
    extends StateNotifier<AsyncValue<List<MovementHistory>>> {
  final String userId;
  final String type;

  MovementHistoryNotifier({required this.userId, required this.type})
    : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiClient.getMovementHistory(userId, type: type);
      if (response['success'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        final history = data.map((d) => MovementHistory.fromJson(d)).toList();
        state = AsyncValue.data(history);
      } else {
        // Gerçek veri yoksa mock göster (simulatörde faydalı)
        state = AsyncValue.data(
          List.generate(5, (i) => MovementHistory.mock('move_$i', userId, i)),
        );
      }
    } catch (e) {
      // Bağlantı yoksa mock veri kullan
      state = AsyncValue.data(
        List.generate(5, (i) => MovementHistory.mock('move_$i', userId, i)),
      );
    }
  }
}

final movementHistoryProvider =
    StateNotifierProvider.family<
      MovementHistoryNotifier,
      AsyncValue<List<MovementHistory>>,
      String
    >((ref, userId) {
      return MovementHistoryNotifier(userId: userId, type: 'today');
    });

// Sık gidilen yerler provider
class FrequentPlacesNotifier
    extends StateNotifier<AsyncValue<List<FrequentPlace>>> {
  final String userId;

  FrequentPlacesNotifier(this.userId) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiClient.getMovementHistory(
        userId,
        type: 'frequent',
      );
      if (response['success'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        final places = data.map((d) => FrequentPlace.fromJson(d)).toList();
        state = AsyncValue.data(places);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = const AsyncValue.data([]);
    }
  }
}

final frequentPlacesProvider =
    StateNotifierProvider.family<
      FrequentPlacesNotifier,
      AsyncValue<List<FrequentPlace>>,
      String
    >((ref, userId) {
      return FrequentPlacesNotifier(userId);
    });

// Onboarding State
final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

// Current Page Index for Navigation
final currentNavigationIndexProvider = StateProvider<int>((ref) => 0);

// Ghost Mode Provider
final ghostModeProvider = StateProvider<bool>((ref) => false);

// Mock Invitations Provider
