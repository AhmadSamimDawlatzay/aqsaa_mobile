import 'package:flutter/foundation.dart';
import '../models/notification_models.dart';
import 'session_controller.dart';

class NotificationInboxController extends ChangeNotifier {
  NotificationInboxController({required this.session});

  final SessionController session;
  final List<InboxNotification> _items = [];
  final Set<String> _confirmedRead = {};
  List<InboxNotification> get items => List.unmodifiable(_items);
  int? unreadCount;
  Object? listError;
  Object? countError;
  Object? loadMoreError;
  bool loading = false;
  bool loadingMore = false;
  bool markingAll = false;
  int page = 0;
  int lastPage = 1;
  int _listGeneration = 0;
  int _countGeneration = 0;
  bool _disposed = false;

  bool get canLoadMore => page > 0 && page < lastPage;

  Future<void> initialize() async {
    await Future.wait([refresh(), refreshUnreadCount()]);
  }

  Future<void> refresh() async {
    final generation = ++_listGeneration;
    loading = true;
    listError = null;
    loadMoreError = null;
    _emit();
    try {
      final result = await session.fetchNotifications();
      if (!_currentList(generation)) return;
      _replace(result.items);
      page = result.page;
      lastPage = result.lastPage;
    } catch (error) {
      if (!_currentList(generation)) return;
      listError = error;
    } finally {
      if (_currentList(generation)) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !canLoadMore) return;
    final generation = _listGeneration;
    loadingMore = true;
    loadMoreError = null;
    _emit();
    try {
      final result = await session.fetchNotifications(page: page + 1);
      if (!_currentList(generation)) return;
      final byId = {for (final item in _items) item.id: item};
      for (final item in result.items) {
        byId[item.id] = _normalized(item);
      }
      _items
        ..clear()
        ..addAll(byId.values);
      page = result.page;
      lastPage = result.lastPage;
    } catch (error) {
      if (_currentList(generation)) loadMoreError = error;
    } finally {
      if (_currentList(generation)) {
        loadingMore = false;
        _emit();
      }
    }
  }

  Future<void> refreshUnreadCount() async {
    final generation = ++_countGeneration;
    countError = null;
    try {
      final count = await session.fetchUnreadNotificationCount();
      if (!_currentCount(generation)) return;
      unreadCount = count;
    } catch (error) {
      if (!_currentCount(generation)) return;
      countError = error;
      unreadCount = null;
    }
    _emit();
  }

  Future<InboxNotification> markRead(InboxNotification item) async {
    final readAt = await session.markNotificationRead(item.id);
    if (_disposed) return item;
    _confirmedRead.add(item.id);
    final updated = item.markRead(readAt);
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    if (index >= 0) _items[index] = updated;
    _emit();
    await refreshUnreadCount();
    return updated;
  }

  Future<void> markAllRead() async {
    if (markingAll) return;
    markingAll = true;
    _emit();
    try {
      await session.markAllNotificationsRead();
      if (_disposed) return;
      final now = DateTime.now().toUtc();
      for (var index = 0; index < _items.length; index++) {
        final item = _items[index];
        _confirmedRead.add(item.id);
        _items[index] = item.markRead(item.readAt ?? now);
      }
      _emit();
      await refreshUnreadCount();
    } finally {
      if (!_disposed) {
        markingAll = false;
        _emit();
      }
    }
  }

  void _replace(List<InboxNotification> incoming) {
    final byId = <String, InboxNotification>{};
    for (final item in incoming) {
      byId[item.id] = _normalized(item);
    }
    _items
      ..clear()
      ..addAll(byId.values);
  }

  InboxNotification _normalized(InboxNotification item) =>
      _confirmedRead.contains(item.id) && !item.isRead
      ? item.markRead(DateTime.now().toUtc())
      : item;

  bool _currentList(int generation) =>
      !_disposed && generation == _listGeneration;
  bool _currentCount(int generation) =>
      !_disposed && generation == _countGeneration;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _listGeneration++;
    _countGeneration++;
    _items.clear();
    unreadCount = null;
    super.dispose();
  }
}
