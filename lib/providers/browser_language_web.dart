import 'dart:html' show window;

/// Web implementation: reads navigator.language from the browser.
/// Format varies by browser:
/// - Chrome/Samsung/Edge: "tr-TR", "en-US"
/// - Firefox: "tr", "en" (no region suffix)
/// - Opera/Brave: same as Chrome (Chromium-based)
String getBrowserLanguage() {
  final lang = window.navigator.language;
  // Firefox returns short codes, Chromium returns full locale.
  // Normalize to "tr", "en", "nl" by taking the first 2 chars.
  return lang.length >= 2 ? lang.substring(0, 2).toLowerCase() : lang;
}
