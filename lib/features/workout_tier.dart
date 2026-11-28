import 'package:flutter/material.dart';

import '../ranking/ranking_data.dart';
import 'workout_qr_session.dart';

/// The user's personal progression tier. Only verified QR sessions award XP.
class WorkoutTier {
  const WorkoutTier({
    required this.name,
    required this.minimumXp,
    required this.colorValue,
    required this.description,
  });

  final String name;
  final int minimumXp;
  final int colorValue;
  final String description;

  Color get color => Color(colorValue);

  static const List<WorkoutTier> all = [
    WorkoutTier(name: '아이언', minimumXp: 0, colorValue: 0xFF87919D, description: '운동 여정을 시작했어요.'),
    WorkoutTier(name: '브론즈', minimumXp: 100, colorValue: 0xFFB87950, description: '꾸준히 운동 인증을 쌓고 있어요.'),
    WorkoutTier(name: '실버', minimumXp: 250, colorValue: 0xFFB8C4D3, description: '활동 기록이 안정적으로 쌓이고 있어요.'),
    WorkoutTier(name: '골드', minimumXp: 450, colorValue: 0xFFE1B84D, description: '꾸준한 활동으로 존재감을 보여주고 있어요.'),
    WorkoutTier(name: '플래티넘', minimumXp: 700, colorValue: 0xFF59BDD3, description: '활발하게 운동에 참여하고 있어요.'),
    WorkoutTier(name: '에메랄드', minimumXp: 1000, colorValue: 0xFF35B987, description: '높은 활동성을 유지하고 있어요.'),
    WorkoutTier(name: '다이아몬드', minimumXp: 1400, colorValue: 0xFF638FE8, description: '상위 활동 단계에 도달했어요.'),
    WorkoutTier(name: '마스터', minimumXp: 1900, colorValue: 0xFFB16AE8, description: '오랜 기간 운동을 이어가고 있어요.'),
    WorkoutTier(name: '그랜드마스터', minimumXp: 2500, colorValue: 0xFFE06B58, description: '매우 높은 활동 기록을 보유하고 있어요.'),
    WorkoutTier(name: '챌린저', minimumXp: 3200, colorValue: 0xFFE9C66B, description: '최고 단계에 도달했어요.'),
  ];

  static WorkoutTier forXp(int xp) {
    final safeXp = xp < 0 ? 0 : xp;
    return all.lastWhere((tier) => safeXp >= tier.minimumXp);
  }

  static int indexForXp(int xp) => all.indexOf(forXp(xp));

  static WorkoutTier? nextForXp(int xp) {
    final index = indexForXp(xp);
    return index >= all.length - 1 ? null : all[index + 1];
  }

  static double progressForXp(int xp) {
    final current = forXp(xp);
    final next = nextForXp(xp);
    if (next == null) return 1;
    return ((xp - current.minimumXp) / (next.minimumXp - current.minimumXp))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static int xpToNext(int xp) {
    final next = nextForXp(xp);
    if (next == null) return 0;
    return (next.minimumXp - xp).clamp(0, next.minimumXp).toInt();
  }

  /// Base participation XP is always awarded once per verified session.
  /// Results and running distance add small bonuses, but never affect public ranks.
  static int xpForSession(WorkoutQrSession session) {
    var xp = 20;
    if (session.isRunning) {
      xp += switch (session.distance) {
        RunningDistance.five => 4,
        RunningDistance.ten => 7,
        RunningDistance.half => 10,
        RunningDistance.full => 13,
        null => 0,
      };
    } else {
      final own = session.teamScore ?? 0;
      final opponent = session.opponentScore ?? 0;
      if (own > opponent) {
        xp += 5;
      } else if (own == opponent) {
        xp += 3;
      }
    }
    return xp;
  }
}
