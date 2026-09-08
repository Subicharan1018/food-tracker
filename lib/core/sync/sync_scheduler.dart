import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth/firebase_auth_rest_service.dart';
import '../local_db/app_database.dart';
import '../network/google_firestore_sync_service.dart';

class SyncSchedulerStatus {
  final bool isSyncing;
  final SyncResult? lastResult;
  final String? error;
  final String? authReason;
  final DateTime? lastSyncTime;

  const SyncSchedulerStatus({
    this.isSyncing = false,
    this.lastResult,
    this.error,
    this.authReason,
    this.lastSyncTime,
  });

  SyncSchedulerStatus copyWith({
    bool? isSyncing,
    SyncResult? lastResult,
    String? error,
    String? authReason,
    DateTime? lastSyncTime,
  }) {
    return SyncSchedulerStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
      error: error,
      authReason: authReason ?? this.authReason,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncScheduler with ChangeNotifier {
  final GoogleFirestoreSyncService _syncService;
  final FirebaseAuthRestService _authService;
  final AppDatabase _db;
  final Duration debounceDuration;

  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _hasPendingRequest = false;
  SyncSchedulerStatus _status = const SyncSchedulerStatus();

  SyncScheduler({
    required GoogleFirestoreSyncService syncService,
    required FirebaseAuthRestService authService,
    required AppDatabase db,
    this.debounceDuration = const Duration(milliseconds: 1000),
  })  : _syncService = syncService,
        _authService = authService,
        _db = db;

  SyncSchedulerStatus get status => _status;

  /// Schedule a sync with debouncing.
  /// Rapid successive calls (e.g. logging 5 meals) reset the timer,
  /// resulting in a single Firestore sync after the last mutation settles.
  void scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      syncNow();
    });
  }

  /// Immediately execute two-way sync without debouncing
  /// (e.g., on app launch, lifecycle resume, or manual retry).
  Future<SyncResult?> syncNow() async {
    _debounceTimer?.cancel();

    if (_isSyncing) {
      _hasPendingRequest = true;
      return null;
    }

    _isSyncing = true;
    _status = _status.copyWith(isSyncing: true, error: null);
    notifyListeners();

    try {
      // Guard: Check auth state before constructing network requests
      final authState = await _authService.getAuthState();
      if (authState is AuthFailure) {
        _isSyncing = false;
        _status = _status.copyWith(
          isSyncing: false,
          error: authState.message,
          authReason: authState.reason,
        );
        notifyListeners();
        return null;
      }

      final result = await _syncService.syncAll(_db);

      _status = _status.copyWith(
        isSyncing: false,
        lastResult: result,
        lastSyncTime: result.success ? result.timestamp : _status.lastSyncTime,
        error: result.success ? null : result.errorMessage,
        authReason: null,
      );
      notifyListeners();
      return result;
    } catch (e) {
      _status = _status.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
      notifyListeners();
      return null;
    } finally {
      _isSyncing = false;
      if (_hasPendingRequest) {
        _hasPendingRequest = false;
        // Trigger any mutation that arrived while syncing
        scheduleSync();
      }
    }
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
