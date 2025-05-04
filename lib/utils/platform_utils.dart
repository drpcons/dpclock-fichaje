import 'package:flutter/foundation.dart';

String getOrigin() {
  if (kIsWeb) {
    return 'https://drpcons.github.io';
  }
  return 'app://fichaje';
} 