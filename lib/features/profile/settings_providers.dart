import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/hive_boxes.dart';

/// A setting kept in the Hive settings box so it survives restarts. Reads and
/// writes are guarded: the box isn't open in some tests or if Hive failed to
/// start, and a setting must never crash the app.
class _PersistedSetting<T> extends StateNotifier<T> {
  _PersistedSetting(this._key, T fallback,
      {required this.decode, required this.encode})
      : super(_read(_key, fallback, decode));

  final String _key;
  final T Function(Object?) decode;
  final Object Function(T) encode;

  static T _read<T>(String key, T fallback, T Function(Object?) decode) {
    try {
      final raw = HiveBoxes.settings.get(key);
      return raw == null ? fallback : decode(raw);
    } catch (_) {
      return fallback;
    }
  }

  void set(T value) {
    state = value;
    try {
      HiveBoxes.settings.put(_key, encode(value));
    } catch (_) {/* not persisted; still applied for this session */}
  }
}

/// App theme: system, dark (default) or light.
final themeModeProvider =
    StateNotifierProvider<_PersistedSetting<ThemeMode>, ThemeMode>((ref) {
  return _PersistedSetting<ThemeMode>(
    'themeMode',
    ThemeMode.dark,
    decode: (raw) => ThemeMode.values
        .firstWhere((m) => m.name == raw, orElse: () => ThemeMode.dark),
    encode: (m) => m.name,
  );
});

/// Keep playing similar songs when the queue ends.
final autoplayEnabledProvider =
    StateNotifierProvider<_PersistedSetting<bool>, bool>((ref) {
  return _PersistedSetting<bool>(
    'autoplay',
    true,
    decode: (raw) => raw == true,
    encode: (v) => v,
  );
});
