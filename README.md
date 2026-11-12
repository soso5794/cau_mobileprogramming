
# 운동 Assist 🏃

날씨 기반 운동 지수 + 주간 운동 계획 + AI 운동 도우미 앱 (모바일프로그래밍 팀 프로젝트)

## 팀원 GitHub ID

- [CircusHan](https://github.com/CircusHan)

## 이번 주 제출: Stateful widgets

이전 Routing screens 제출을 바탕으로 `StatefulWidget`을 활용한 **알림 설정**과
**검색 가능한 운동 선택창**을 추가했습니다. 사용자의 입력에 따라 `setState()`로
화면을 갱신하고, 임시 변경과 저장된 데이터를 구분합니다. 기존 4개 탭과 URL 라우팅은 유지합니다.

- **[Stateful widgets 구현 설명·시연 순서](docs/STATEFUL_ASSIGNMENT.md)**
- [이전 Routing screens 과제](docs/ROUTING_ASSIGNMENT.md)
- [아키텍처](docs/ARCHITECTURE.md) · [클래스 계약](docs/CLASS_DESIGN.md)
- [실행 검증과 한계](docs/VALIDATION.md)
- Flutter **3.44.0 이상**, Dart **3.12.0 이상** 필요
- 이미지/폰트 assets 미사용 (`assets/` 불필요)
- 팀 저장소를 **2026년 12월 25일까지 public**으로 유지해야 합니다.

## 화면 구성

| 화면 | 파일 | 설명 |
|---|---|---|
| 로그인 | `lib/screens/login_screen.dart` | 아이디/비밀번호 입력, 새로가입·로그인 버튼 |
| 회원가입 | `lib/screens/signup_screen.dart` | 이름, 나이, 아이디, 비밀번호 입력 |
| 메인 틀 | `lib/screens/home_shell.dart` | 하단 탭 4개 (운동선택 / Plan / 운동분석 / AI) |
| 운동선택 | `lib/screens/sport_select_screen.dart` | ⊕로 선호 운동 여러 개 선택 → 버튼으로 표시 |
| 운동 선택창 | `lib/screens/sport_picker_sheet.dart` | 검색·다중 선택·선택 개수, 완료 시 반영·취소 시 폐기 |
| 알림 설정 | `lib/screens/notification_settings_screen.dart` | 상단 종 아이콘 → 종류·시점·방해금지 설정, 저장·변경 취소 |
| 위치 입력 | `lib/screens/location_screen.dart` | 운동별 자주 가는 위치 저장, 선택 시 운동분석 탭으로 이동 |
| 운동분석 | `lib/screens/analysis_screen.dart` | 날씨(기온·습도·바람·강수·미세먼지), 요일별 지수 색상, 운동지수, AI 조언 |
| Week Plan | `lib/screens/plan_screen.dart` | 운동×요일 적합도 표(O/△/X), 요일별 추천 일정 |
| AI 도우미 | `lib/screens/ai_chat_screen.dart` | 운동 질문 챗봇 (현재 더미 응답) |

공유 데이터는 `lib/models/app_state.dart` (ChangeNotifier + Provider), 화면 이동은 `lib/routing/app_router.dart`가 관리합니다.


## 디자인 (2차 제출: Widget Decoration)

- `lib/theme/app_theme.dart` 에서 앱 전체 테마를 한 곳에 정의
  - `ColorScheme.fromSeed` (브랜드 파랑 `#1E6BFF`), 라이트/다크 테마, 버튼·슬라이더·스낵바 컴포넌트 테마
  - 공통 위젯: `SectionCard`(둥근 카드 + 그림자), `SectionTitle`, `appInputDecoration`(둥근 입력칸)
  - `ScoreColors`: 운동지수 색 (좋음 초록 / 보통 주황 / 나쁨 빨강)
- 운동별 대표 색 (`sportColor`) — 운동 버튼, 표, 추천 일정에 통일 적용
- 다크모드 토글 (상단 AppBar 버튼)
- 애니메이션: 점수 게이지 `TweenAnimationBuilder`, 요일 선택 `AnimatedContainer`
- 화면별: 로그인 그라데이션 배경, NavigationBar(M3), 채팅 말풍선 꼬리 + 추천 질문 칩

## 실행

```bash
flutter pub get
flutter run
```

## 현재 단계 / 다음 단계

- 날씨 데이터와 AI 답변은 **더미 데이터**입니다.
- 알림은 **설정 UI 시연**입니다. 실제 발송·권한 요청은 없으며, 설정은 사용자 ID별로 앱 실행 중에만 유지됩니다.
- TODO: 날씨 API 연결 (`AppState.weatherFor`), LLM API 연결 (`AiChatScreen._askAi`, `AnalysisScreen._advice`), 로그인 정보 저장(persistence)

# cau_mobileprogramming
mobileprogramming assignment
