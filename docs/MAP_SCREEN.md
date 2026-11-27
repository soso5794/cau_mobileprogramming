# 지도 탭 (MapScreen)

## 기능
- OpenStreetMap 지도(flutter_map + latlong2). API 키가 필요 없어요.
- 종목 필터: 전체 / 농구 / 런닝 / 축구. 내 관심 종목이 앞에 와요.
- 마커를 누르면 상세 시트가 열려요.
  - 기존 `WeatherService`로 그 좌표의 실시간 날씨를 받아와요.
  - 기존 `ExerciseConditions` 규칙으로 종목별 지수와 12시간 내 추천 시간을 보여줘요.
- 상세 시트의 칩을 눌러 종목별로 "내 운동 장소"에 저장하거나 해제할 수 있어요.
  - 기존 `AppState.addLocation`을 그대로 써요.
  - 저장한 장소는 마커와 카드에 ★로 표시돼요.
- `내 위치` 버튼(geolocator):
  - 위치 권한은 버튼을 눌렀을 때만 요청해요.
  - 위치를 받으면 하단 카드가 가까운 순으로 정렬돼요.
  - 실패하면 스낵바로 이유를 알려줘요.
- `내 장소` 칩을 누르면 저장한 장소 목록이 열려요.
  - 직접 입력한 장소(좌표 없음)도 함께 보여줘요.
  - 기존 장소 입력 화면으로 이동하는 링크가 있어요.

## 파일
| 파일 | 역할 |
|---|---|
| `lib/map/sport_place.dart` | 장소 데이터(15곳), 하버사인 거리, 필터/정렬. 순수 Dart라 단위 테스트가 가능해요. |
| `lib/map/location_service.dart` | `LocationService` 인터페이스와 geolocator 구현. 테스트에서 가짜로 교체할 수 있어요. |
| `lib/map/place_sheet.dart` | 마커 상세 시트. FutureBuilder로 날씨를 표시해요. |
| `lib/screens/map_screen.dart` | 지도 탭 화면 |
| `test/map_test.dart` | 로직 테스트 4개, 위젯 테스트 3개 |

## 기존 코드에서 바뀐 것
- `AppState`: 생성자에 `locationService`를 추가했어요. `weatherService`와 같은 주입 방식이에요.
- `pubspec.yaml`: `flutter_map`, `latlong2`, `geolocator`를 추가했어요.
- `AndroidManifest.xml`: 위치 권한 2줄(COARSE/FINE)을 추가했어요.
- `test/support/member_test_support.dart`:
  - `makeApp`에 날씨/위치 서비스 주입 인자를 추가했어요.
  - UI 테스트에서는 지도 타일(네트워크)을 꺼요.

## 한계
- 장소 좌표는 공원과 운동장의 대략적인 위치예요.
- 코트 예약과 점유 상태는 표시하지 않아요.
- 저장한 장소는 기존 `AppState`와 마찬가지로 메모리에만 있어요(앱을 재시작하면 사라져요).
- 다음 단계: 모집글 DB가 생기면 `SportPlace`에 모집글 수와 시간을 붙여 매치 탭과 연결해요.

## 장소·주소 검색 (모집글과 같은 서비스)
- 지도 상단 검색창 → `PlaceSearchService` → 로컬 서버 `/api/places/search` → Geoapify.
- 결과를 고르면 지도가 이동하고 빨간 핀이 생겨요. 핀을 누르면 기존 날씨·지수·즐겨찾기 시트가 열려요.
- `GEOAPIFY_API_KEY`는 `server/.env`에만 둬요(Git 제외). 서버가 꺼져 있으면 안내 문구만 표시돼요.

## 모집글 지도 (알바몬식)
- 모집글을 쓸 때 지도에서 찍은 좌표가 있으면, 지도에 `모집 n` 말풍선 핀으로 표시돼요.
- 좌표가 없어도 장소명이 지도 운동 장소와 같으면(예: 보라매공원) 그 위치에 표시돼요.
- 같은 장소의 글은 한 핀으로 묶여요(약 10m 단위). 종목 필터를 따르고, 종료 시간이 지난 모집은 빠져요.
- 핀을 누르면 그 장소의 모집글 목록이 열려요. 글을 누르면 기존 모집글 상세(`/community/posts/:id`)로 이동해요.
- 목록 창에서 "이곳 날씨", "모집글 쓰기"로 이어갈 수 있어요.
- `모집글 n` 칩으로 핀을 켜고 끌 수 있어요. 예시(데모) 모집글은 좌표가 없어 지도에 뜨지 않아요.
- 코드: `lib/map/recruitment_pins.dart`(순수 Dart 묶기 로직), 테스트: `test/map_recruitment_test.dart`
