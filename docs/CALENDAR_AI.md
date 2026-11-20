# 캘린더·AI 추가 구현 · 2026-11-18

## 캘린더

마이페이지에 월별 캘린더를 직접 배치했다. 날짜별 점 표시, 선택일 일정 목록, 월 이동/오늘 버튼, 일정 CRUD 및 완료 토글을 제공한다. 시간 겹침은 경고 후 사용자가 저장 여부를 결정한다. 일정은 기기 현지 시각으로 저장되며 여행 시 시간대를 자동 변환하는 기능은 없다. 자정을 넘는 운동은 시작 날짜에 표시한다.

`WorkoutEvent`는 불변 모델이며 `MemberProfile.events`에 저장된다. 이전 저장 데이터에서 events가 없으면 빈 목록으로 복원하므로 기존 회원을 지우지 않는다. 일정 저장과 삭제는 현재 로그인 계정을 확인하고 기존 저장 성공 후 확정 규칙을 사용한다. 팀 모집/가입과 자동 연동하거나 OS 알림을 발송하지 않는다.

## AI

`AiGateway` 인터페이스 / HTTP 구현 → `server/index.mjs` → OpenAI Responses API. 앱에는 제공업체 API 키를 포함하지 않는다. 서버는 local-only 프로토타입으로 동작한다. 서버 문서에 실행·에뮬레이터·HTTPS 전환·키 설정·미구현 범위를 기록했다.

최근 사용자/AI 대화만 전송하며 이메일·프로필·캘린더는 자동으로 전송하지 않는다. 질문 전 화면에서 전송 내용을 알린다. 재시도 시 사용자 질문을 중복 추가하지 않는다. 실패 응답을 AI 답변으로 저장하지 않으며 화면 이탈 후 늦게 도착한 응답은 표시하지 않는다.

사용자 결정: OpenAI API 선택, 키 설정은 나중에 진행. 따라서 실제 유료 API 호출은 하지 않았으며 테스트 대역으로 요청/응답/실패 처리를 검증한다.

## 변경 파일

- `lib/calendar/`: 일정 모델, 편집 다이얼로그, 캘린더 카드.
- `lib/members/member_models.dart`, `member_controller.dart`: 계정별 일정 저장.
- `lib/ai/ai_gateway.dart`, `screens/ai_chat_screen.dart`: HTTP 연결/대화 UI.
- `models/app_state.dart`, `routing/app_router.dart`, `screens/profile_screen.dart`: 기존 흐름 연결.
- `server/`: 비밀 키를 보관하는 로컬 프록시, 환경변수 예시, 서버 테스트.
- Android manifest/debug network security 및 `pubspec.yaml`: HTTP 권한/의존성.

공식 구현 기준: https://developers.openai.com/api/reference/resources/responses/methods/create

## 검증 결과

- Flutter 정적 분석: 문제 없음.
- Flutter 테스트 46개 통과. 기존 36개 회귀 테스트와 일정 마이그레이션/계정 분리/저장/윤년/CRUD/완료/AI HTTP/재시도 검증 포함.
- Node 서버 테스트 8개 통과. 실제 OpenAI 호출은 테스트 대역으로 대체.
- 웹 release 빌드 및 Android debug APK 빌드 성공.
- 실제 로컬 서버 `/health` 응답 확인: `configured: false`, 기본 모델 `gpt-4.1-mini`. API 키 미설정이므로 유료 모델 응답은 확인하지 않았음.
- 기존 Android Kotlin 구성의 향후 호환성 경고는 남아 있으며 이번 빌드는 성공함.
