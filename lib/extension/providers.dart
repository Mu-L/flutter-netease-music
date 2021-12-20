import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

extension ProvidersException<State> on ProviderBase<AsyncValue<State>> {
  ProviderListenable<AsyncValue<State>> logErrorOnDebug() {
    return select((value) {
      if (value is AsyncError) {
        final error = value as AsyncError;
        debugPrint('$this: ${error.error} \n ${error.stackTrace}');
      }
      return value;
    });
  }
}