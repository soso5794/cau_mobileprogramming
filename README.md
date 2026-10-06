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

## 실행

```bash
flutter pub get
flutter run
```

## 현재 단계 / 다음 단계

- 날씨 데이터와 AI 답변은 **더미 데이터**입니다.
- TODO: 날씨 API 연결 (`AppState.weatherFor`), LLM API 연결 (`AiChatScreen._askAi`, `AnalysisScreen._advice`), 로그인 정보 저장(persistence)
