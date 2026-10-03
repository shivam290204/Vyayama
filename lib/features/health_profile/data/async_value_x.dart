import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Safe access to the data of an [AsyncValue] without throwing.
extension AsyncValueDataX<T> on AsyncValue<T> {
  /// The current data, or null while loading or after an error.
  T? get dataOrNull => hasValue ? value : null;
}
