import 'package:flutter/foundation.dart';
import 'platform_utils_web.dart' if (dart.library.io) 'platform_utils_mobile.dart';

String getOrigin() {
  if (kIsWeb) {
    try {
      return getPlatformOrigin();
    } catch (e) {
      return 'https://drpcons.github.io';
    }
  }
  return 'app://fichaje';
} 