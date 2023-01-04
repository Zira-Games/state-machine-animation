import 'dart:core';
import 'dart:async';
import 'dart:collection';
import 'package:clock/clock.dart';

class CacheEntry<V> {
  final V _cacheObject;
  final DateTime _createTime;

  CacheEntry(this._cacheObject, this._createTime);

  DateTime get createTime => _createTime;

  get cacheObject => _cacheObject;
}

/// A FIFO cache. Its entries will expire after a given time period.
///
/// The cache entry will get remove when it is the first inserted entry and
/// cache reach its limited size, or when it is expired.
///
/// You can use markAsInFlight to indicate that there will be a set call after.
/// Then before this key's corresponding value is set, all the other get to this
/// key will wait on the same [Future].
class ExpireCache<K, V> {
  /// The clock that uses to compute create_timestamp and expire.
  final Clock clock;

  /// The duration between entry create and expire. Default 120 seconds
  final Duration expireDuration;

  /// The duration between each garbage collection. Default 180 seconds.
  final Duration gcDuration;

  /// The upper size limit of [_cache](the cache's max entry number).
  final int sizeLimit;

  /// The internal cache that stores the cache entries.
  final _cache = <K, CacheEntry<V>>{};

  get cache => _cache;

  ExpireCache(
      {this.clock = const Clock(),
      this.expireDuration = const Duration(seconds: 120),
      this.sizeLimit = 100,
      this.gcDuration = const Duration(seconds: 180)})
      : assert(sizeLimit > 0) {
    Timer.periodic(gcDuration, (Timer t) => _expireOutdatedEntries());
  }

  /// Sets the value associated with [key]. The Future completes with null when
  /// the operation is complete.
  ///
  /// Setting the same key should make that key the latest key in [_cache].
  V set(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }
    _cache[key] = CacheEntry(value, clock.now());
    if (_cache.length > sizeLimit) {
      removeFirst();
    }
    return value;
  }

  /// Expire all the outdated cache and inflight entries.
  ///
  /// [_cache] and [_inflightSet] are [LinkedHashMap], which is iterated by time
  /// order. So we just need to stop when we sees the first not expired value.
  _expireOutdatedEntries() {
    _cache.keys
        .takeWhile((value) => isCacheEntryExpired(value))
        .toList()
        .forEach(_cache.remove);
  }

  /// The number of entry in the cache.
  int length() => _cache.length;

  /// Returns true if there is no entry in the cache. Doesn't matter if there is
  /// any inflight entry.
  bool isEmpty() => _cache.isEmpty;

  void removeFirst() {
    _cache.remove(_cache.keys.first);
  }

  /// Removes the value associated with [key]. The Future completes with null
  /// when the operation is complete.
  invalidate(K key) {
    _cache.remove(key);
  }

  bool isCacheEntryExpired(K key) =>
      clock.now().difference(_cache[key]!._createTime) > expireDuration;

  /// Returns the value associated with [key].
  ///
  /// If the [key] is inflight, it will get the [Future] of that inflight key.
  /// Will invalidate the entry if it is expired.
  V? get(K key) {
    if (_cache.containsKey(key) && isCacheEntryExpired(key)) {
      _cache.remove(key);
      return null;
    }
    return _cache[key]?._cacheObject;
  }

  void clear() {
    _cache.clear();
  }
}
