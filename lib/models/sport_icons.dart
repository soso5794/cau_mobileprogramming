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
