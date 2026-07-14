import 'package:flutter/material.dart';
import '../models/job.dart';

// -----------------------------------------------------------------------
// Özel tema extension'ı — uygulamaya özel renkler burada toplanır.
// Tema değişikliği tek noktadan (main.dart → ThemeData) yapılır.
// -----------------------------------------------------------------------

class AppThemeExt extends ThemeExtension<AppThemeExt> {
  /// Kart / yüzey arka plan rengi (Card, Container vb.)
  final Color cardColor;

  /// İkincil metin rengi (açıklamalar, yardımcı metinler)
  final Color textSecondary;

  /// Üçüncül / soluk metin rengi (tarih, etiket gibi)
  final Color textTertiary;

  // -- İş durum renkleri (TÜM ekranlarda tutarlı) --
  final Color statusNotStarted;
  final Color statusInProgress;
  final Color statusWorkCompleted;
  final Color statusClosed;

  const AppThemeExt({
    required this.cardColor,
    required this.textSecondary,
    required this.textTertiary,
    required this.statusNotStarted,
    required this.statusInProgress,
    required this.statusWorkCompleted,
    required this.statusClosed,
  });

  /// Varsayılan koyu tema renkleri (Canlı palet)
  static const defaultDark = AppThemeExt(
    cardColor: Color(0xFF1A2A3A),
    textSecondary: Color(0xFF90A4AE),
    textTertiary: Color(0xFF546E7A),
    statusNotStarted: Color(0xFF607D8B), // Blue Grey
    statusInProgress: Color(0xFFFF6D00), // Dark Orange
    statusWorkCompleted: Color(0xFF00BCD4), // Cyan
    statusClosed: Color(0xFF388E3C), // Dark Green
  );

  /// Varsayılan açık tema renkleri (Canlı palet)
  static const defaultLight = AppThemeExt(
    cardColor: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF757575),
    textTertiary: Color(0xFF9E9E9E),
    statusNotStarted: Color(0xFF607D8B), // Blue Grey
    statusInProgress: Color(0xFFE65100), // Deep Orange (light tema için biraz koyu)
    statusWorkCompleted: Color(0xFF00838F), // Dark Cyan (light tema için okunur)
    statusClosed: Color(0xFF2E7D32), // Dark Green (light tema için okunur)
  );

  /// Verilen JobStatus için doğru rengi döndürür (tek kaynak!).
  Color statusColor(JobStatus status) {
    switch (status) {
      case JobStatus.notStarted:
        return statusNotStarted;
      case JobStatus.inProgress:
        return statusInProgress;
      case JobStatus.workCompleted:
        return statusWorkCompleted;
      case JobStatus.closed:
        return statusClosed;
    }
  }

  @override
  AppThemeExt copyWith({
    Color? cardColor,
    Color? textSecondary,
    Color? textTertiary,
    Color? statusNotStarted,
    Color? statusInProgress,
    Color? statusWorkCompleted,
    Color? statusClosed,
  }) {
    return AppThemeExt(
      cardColor: cardColor ?? this.cardColor,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      statusNotStarted: statusNotStarted ?? this.statusNotStarted,
      statusInProgress: statusInProgress ?? this.statusInProgress,
      statusWorkCompleted: statusWorkCompleted ?? this.statusWorkCompleted,
      statusClosed: statusClosed ?? this.statusClosed,
    );
  }

  @override
  AppThemeExt lerp(ThemeExtension<AppThemeExt>? other, double t) {
    if (other is! AppThemeExt) return this;
    return AppThemeExt(
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      statusNotStarted:
          Color.lerp(statusNotStarted, other.statusNotStarted, t)!,
      statusInProgress:
          Color.lerp(statusInProgress, other.statusInProgress, t)!,
      statusWorkCompleted:
          Color.lerp(statusWorkCompleted, other.statusWorkCompleted, t)!,
      statusClosed: Color.lerp(statusClosed, other.statusClosed, t)!,
    );
  }
}

// -----------------------------------------------------------------------
// BuildContext extension — kısa erişim için
// Kullanım: context.appExt.cardColor, context.appExt.statusColor(status)
// -----------------------------------------------------------------------

extension AppThemeContext on BuildContext {
  /// Uygulama tema extension'ına kısa erişim.
  /// Sistem temasına göre otomatik olarak dark/light varyantı döner.
  AppThemeExt get appExt {
    final ext = Theme.of(this).extension<AppThemeExt>();
    if (ext != null) return ext;
    // Fallback: sistem parlaklığına göre uygun temayı döndür
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark
        ? AppThemeExt.defaultDark
        : AppThemeExt.defaultLight;
  }

  /// ColorScheme'e kısa erişim
  ColorScheme get cs => Theme.of(this).colorScheme;
}
