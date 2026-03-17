import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/core/models/circle_model.dart';
import 'package:tracker_app/core/providers/auth_provider.dart';
import 'package:tracker_app/core/services/api_client.dart';

class CircleState {
  final CircleModel? circle;
  final bool isLoading;
  final String? error;

  CircleState({this.circle, this.isLoading = true, this.error});

  CircleState copyWith({
    CircleModel? circle,
    bool clearCircle = false,
    bool? isLoading,
    String? error,
  }) {
    return CircleState(
      circle: clearCircle ? null : (circle ?? this.circle),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class CircleNotifier extends StateNotifier<CircleState> {
  final Ref _ref;

  CircleNotifier(this._ref) : super(CircleState(isLoading: true)) {
    fetchCircle();
  }

  Future<void> fetchCircle() async {
    state = state.copyWith(isLoading: true, error: null);
    await _performFetch();
  }

  /// Silently update circle data for real-time tracking
  Future<void> silentFetch() async {
    await _performFetch();
  }

  Future<void> _performFetch() async {
    try {
      final response = await ApiClient.getCircle();
      if (response['success'] == true && response['data'] != null) {
        var circle = CircleModel.fromJson(response['data']);
        
        // Mevcut kullanıcının premium durumunu AuthProvider (asıl kaynak) ile eşitle
        final currentUser = _ref.read(authProvider).user;
        if (currentUser != null) {
          final updatedMembers = circle.members.map((m) {
            if (m.id == currentUser.id) {
              return m.copyWith(isPremium: currentUser.isPremium);
            }
            return m;
          }).toList();
          circle = circle.copyWith(members: updatedMembers);
        }

        state = state.copyWith(
          circle: circle,
          isLoading: false,
          clearCircle: false,
        );
      } else {
        state = state.copyWith(isLoading: false, clearCircle: true);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> createCircle(String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiClient.createCircle(name);
      if (response['success'] == true) {
        await fetchCircle();
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: response['message']);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> joinCircle(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiClient.joinCircle(code);
      if (response['success'] == true) {
        await fetchCircle();
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: response['message']);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> leaveCircle(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiClient.leaveCircle(id);
      if (response['success'] == true) {
        state = state.copyWith(isLoading: false, clearCircle: true);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: response['message']);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final circleProvider = StateNotifierProvider<CircleNotifier, CircleState>((
  ref,
) {
  return CircleNotifier(ref);
});
