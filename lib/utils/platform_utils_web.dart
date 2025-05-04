// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String getPlatformOrigin() {
  return html.window.location.origin ?? 'https://drpcons.github.io';
} 