import 'package:flutter/material.dart';

/// 앱 전체 디자인을 한 곳에서 정의하는 파일. (10강: Themes)
///
/// 위젯마다 색과 글꼴을 직접 적으면, 나중에 색 하나를 바꿀 때 파일 전체를 뒤져야 한다.
/// 그래서 ThemeData에 한 번만 정의하고, 화면에서는 Theme.of(context)로 꺼내 쓴다.
class AppTheme {
  AppTheme._(); // 객체를 만들 필요 없는 "모음집" 클래스라 생성자를 막아둠

  /// 브랜드 색(seed). 로고의 파란 체크 표시에서 따온 색.
  /// [10강] ColorScheme.fromSeed: 색 하나만 주면 primary/secondary/surface 등 전체 팔레트를 자동으로 만든다.
  static const Color seed = Color(0xFF1E6BFF);

  /// 로그인 배경 등에 쓰는 그라데이션 색
  static const Color gradientStart = Color(0xFF1E6BFF);
  static const Color gradientEnd = Color(0xFF00C2D1);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final isDark = brightness == Brightness.dark;

    // 둥근 모서리를 앱 전체에서 같은 값으로 맞춘다
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 배경을 순백 대신 아주 연한 회청색으로 → 흰 카드가 떠 보이는 효과
      scaffoldBackgroundColor: isDark ? scheme.surface : const Color(0xFFF4F6FB),

      // [10강] 컴포넌트 테마: 앱 안의 모든 FilledButton / OutlinedButton 모양을 한 번에 정한다
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 5),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// 운동 지수(0~100)에 따른 색. 여러 화면에서 같은 기준을 쓰려고 여기 모았다.
class ScoreColors {
  ScoreColors._();

  static const Color good = Color(0xFF22C55E); // 70점 이상: 초록
  static const Color normal = Color(0xFFF59E0B); // 40~69점: 주황
  static const Color bad = Color(0xFFEF4444); // 40점 미만: 빨강

  static Color of(int score) {
    if (score >= 70) return good;
    if (score >= 40) return normal;
    return bad;
  }

  static String label(int score) {
    if (score >= 70) return '좋음';
    if (score >= 40) return '보통';
    return '나쁨';
  }
}

/// 입력칸 공통 꾸미기: 둥근 모서리 + 앞쪽 아이콘 + 연한 배경
InputDecoration appInputDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  IconData? icon,
  Widget? suffix,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: scheme.surfaceContainerHighest.withAlpha(110),
    border: border(Colors.transparent),
    enabledBorder: border(Colors.transparent),
    focusedBorder: border(scheme.primary, 2), // 선택된 칸만 파란 테두리
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 2),
  );
}

/// 흰색 둥근 카드 + 부드러운 그림자. Card 대신 직접 만든 재사용 위젯.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (isDark ? scheme.surfaceContainerHigh : Colors.white),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null // 다크모드에선 그림자가 잘 안 보여서 생략
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// 카드 위의 작은 제목 (아이콘 + 글자)
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const SectionTitle({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
