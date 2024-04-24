import 'dart:async';

import 'package:collection/collection.dart';
import 'package:immich_mobile/core/store/model/store_key.model.dart';
import 'package:immich_mobile/core/store/model/store_value.model.dart';
import 'package:immich_mobile/core/store/repository/store.repository.dart';

class StoreKeyNotFoundException implements Exception {
  final StoreKey key;
  const StoreKeyNotFoundException(this.key);

  @override
  String toString() => "Key '${key.name}' not found in Store";
}

/// Key-value store for individual items enumerated in StoreKey.
/// Supports String, int and JSON-serializable Objects
/// Can be used concurrently from multiple isolates
class StoreManager {
  late final StoreRepository _db;
  late final StreamSubscription? _subscription;
  final Map<int, dynamic> _cache = {};

  StoreManager._internal();
  static final StoreManager _instance = StoreManager._internal();

  factory StoreManager(StoreRepository db) {
    if (_instance._subscription == null) {
      _instance._db = db;
      _instance._populateCache();
      _instance._subscription =
          _instance._db.watchStore().listen(_instance._onChangeListener);
    }
    return _instance;
  }

  void dispose() {
    _subscription?.cancel();
  }

  FutureOr<void> _populateCache() async {
    for (StoreKey key in StoreKey.values) {
      final StoreValue? value = await _db.getValue(key);
      if (value != null) {
        _cache[key.id] = value;
      }
    }
  }

  /// clears all values from this store (cache and DB), only for testing!
  Future<void> clear() async {
    _cache.clear();
    return await _db.clearStore();
  }

  /// Returns the stored value for the given key (possibly null)
  T? tryGet<T>(StoreKey<T> key) => _cache[key.id] as T?;

  /// Returns the stored value for the given key or if null the [defaultValue]
  /// Throws a [StoreKeyNotFoundException] if both are null
  T get<T>(StoreKey<T> key, [T? defaultValue]) {
    final value = _cache[key.id] ?? defaultValue;
    if (value == null) {
      throw StoreKeyNotFoundException(key);
    }
    return value;
  }

  /// Watches a specific key for changes
  Stream<T?> watch<T>(StoreKey<T> key) => _db.watchStoreValue(key);

  /// Stores the value synchronously in the cache and asynchronously in the DB
  FutureOr<void> put<T>(StoreKey<T> key, T value) async {
    if (_cache[key.id] == value) return Future.value();
    _cache[key.id] = value;
    return await _db.setValue(key, value);
  }

  /// Removes the value synchronously from the cache and asynchronously from the DB
  Future<void> delete<T>(StoreKey<T> key) async {
    if (_cache[key.id] == null) return Future.value();
    _cache.remove(key.id);
    return await _db.deleteValue(key);
  }

  /// Updates the state in cache if a value is updated in any isolate
  void _onChangeListener(List<StoreValue>? data) {
    if (data != null) {
      for (StoreValue value in data) {
        final key = StoreKey.values.firstWhereOrNull((e) => e.id == value.id);
        if (key != null) {
          _cache[value.id] = value.extract(key.type);
        } else {
          // TODO: log key not found
          // _log.warning("No key available for value id - ${value.id}");
        }
      }
    }
  }
}
