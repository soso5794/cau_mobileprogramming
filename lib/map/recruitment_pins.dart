import '../community/community_data.dart';
import 'sport_place.dart';

/// 지도에 표시할 "모집글 핀" 하나. 같은 장소의 모집글은 한 핀에 묶는다. (알바몬식)
class RecruitmentPin {
  const RecruitmentPin({
    required this.latitude,
    required this.longitude,
    required this.place,
    required this.posts,
  });
  final double latitude, longitude;
  final String place;
  final List<RecruitmentPreview> posts;

  /// 핀 색/아이콘에 쓸 대표 종목 (가장 많은 종목, 동률이면 먼저 나온 종목).
  String get mainSport {
    final counts = <String, int>{};
    for (final p in posts) {
      counts[p.sport] = (counts[p.sport] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }
}

/// 모집글 → 지도 좌표.
/// 1순위: 작성할 때 지도에서 찍은 좌표(recruitmentInput.location)
/// 2순위: 장소명이 지도 운동 장소 목록과 같으면 그 좌표
/// 둘 다 없으면 지도에 올리지 않는다(텍스트로만 쓴 장소).
GeoPoint? recruitmentPoint(RecruitmentPreview post) {
  final location = post.recruitmentInput?.location;
  if (location != null && location.isValid) {
    return GeoPoint(location.latitude, location.longitude);
  }
  final place = SportPlaces.byName(post.place.trim());
  return place == null ? null : GeoPoint(place.latitude, place.longitude);
}

/// 이미 끝난 모집(종료 시간이 지남)은 지도에서 뺀다. 시간 정보가 없는 글은 유지.
bool isRecruitmentOpen(RecruitmentPreview post, DateTime now) {
  final end = post.recruitmentInput?.end;
  return end == null || end.isAfter(now);
}

/// 모집글 목록을 핀 목록으로 변환. [sport]가 있으면 그 종목만.
/// 좌표를 소수 4자리(약 10m)로 반올림해서 같은 장소 글을 한 핀으로 묶는다.
List<RecruitmentPin> recruitmentPins(
  Iterable<RecruitmentPreview> posts, {
  String? sport,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final groups = <String, ({GeoPoint point, List<RecruitmentPreview> posts})>{};
  for (final post in posts) {
    if (sport != null && post.sport != sport) continue;
    if (!isRecruitmentOpen(post, at)) continue;
    final point = recruitmentPoint(post);
    if (point == null) continue;
    final key =
        '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
    groups.putIfAbsent(key, () => (point: point, posts: [])).posts.add(post);
  }
  return [
    for (final g in groups.values)
      RecruitmentPin(
        latitude: g.point.latitude,
        longitude: g.point.longitude,
        place: g.posts.first.place,
        posts: List.unmodifiable(g.posts),
      ),
  ];
}

/// 지도 위치가 없어 핀으로 못 올린 (진행 중) 모집글 수. 안내 문구용.
int unmappedRecruitmentCount(Iterable<RecruitmentPreview> posts,
        {String? sport, DateTime? now}) =>
    posts
        .where((p) =>
            (sport == null || p.sport == sport) &&
            isRecruitmentOpen(p, now ?? DateTime.now()) &&
            recruitmentPoint(p) == null)
        .length;
