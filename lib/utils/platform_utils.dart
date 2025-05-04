// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String getOrigin() {
  if (const bool.fromEnvironment('dart.library.js_util')) {
    return html.window.location.origin ?? 'https://drpcons.github.io';
  }
  return 'app://fichaje';
} 