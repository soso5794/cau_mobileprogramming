
# 운동 Assist 🏃

날씨 기반 운동 지수 + 주간 운동 계획 + AI 운동 도우미 앱 (모바일프로그래밍 팀 프로젝트)

## 화면 구성

| 화면 | 파일 | 설명 |
|---|---|---|
| 로그인 | `lib/screens/login_screen.dart` | 아이디/비밀번호 입력, 새로가입·로그인 버튼 |
| 회원가입 | `lib/screens/signup_screen.dart` | 이름, 나이, 아이디, 비밀번호 입력 |
| 메인 틀 | `lib/screens/home_shell.dart` | 하단 탭 4개 (운동선택 / Plan / 운동분석 / AI) |
| 운동선택 | `lib/screens/sport_select_screen.dart` | ⊕로 선호 운동 여러 개 선택 → 버튼으로 표시 |
| 위치 입력 | `lib/screens/location_screen.dart` | 운동별 자주 가는 위치 저장, 선택 시 운동분석 탭으로 이동 |
| 운동분석 | `lib/screens/analysis_screen.dart` | 날씨(기온·습도·바람·강수·미세먼지), 요일별 지수 색상, 운동지수, AI 조언 |
| Week Plan | `lib/screens/plan_screen.dart` | 운동×요일 적합도 표(O/△/X), 요일별 추천 일정 |
| AI 도우미 | `lib/screens/ai_chat_screen.dart` | 운동 질문 챗봇 (현재 더미 응답) |

공유 상태는 `lib/models/app_state.dart` (ChangeNotifier + Provider).


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
- TODO: 날씨 API 연결 (`AppState.weatherFor`), LLM API 연결 (`AiChatScreen._askAi`, `AnalysisScreen._advice`), 로그인 정보 저장(persistence)

# cau_mobileprogramming
mobileprogramming assignment
