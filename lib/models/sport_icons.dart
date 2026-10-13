import 'package:flutter/material.dart';

/// 운동 이름 → 아이콘. 여러 화면에서 같이 쓰려고 따로 뺐다.
IconData sportIcon(String sport) {
  switch (sport) {
    case '농구':
      return Icons.sports_basketball;
    case '런닝':
      return Icons.directions_run;
    case '요트':
      return Icons.sailing;
    case '등산':
      return Icons.terrain;
    case '카약':
      return Icons.kayaking;
    case '자전거':
      return Icons.directions_bike;
    default:
      return Icons.fitness_center;
  }
}

/// 운동 이름 → 대표 색. 운동 버튼, Plan 표, 추천 일정에서 같은 색을 쓴다.
Color sportColor(String sport) {
  switch (sport) {
    case '농구':
      return const Color(0xFFFF7A1A); // 농구공 주황
    case '런닝':
      return const Color(0xFF1E6BFF); // 파랑
    case '요트':
      return const Color(0xFF0EA5E9); // 바다 하늘색
    case '등산':
      return const Color(0xFF16A34A); // 산 초록
    case '카약':
      return const Color(0xFF0D9488); // 청록
    case '자전거':
      return const Color(0xFF8B5CF6); // 보라
    default:
      return Colors.blueGrey;
  }
}
