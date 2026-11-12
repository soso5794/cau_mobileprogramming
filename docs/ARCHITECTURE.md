# 운동 Assist — Routing screens 아키텍처

기준: `soso5794/cau_mobileprogramming` main, `268161653d878557a2ff8940f007ad40433fcabc`.
OUTIME exerciseapp과 별도 앱이며 기존 운동 Assist의 화면·Provider 상태를 확장한다.

- `ExerciseAssistApp`이 `GoRouter`를 한 번 생성하고 dispose한다. 테마 변경 때 다시 만들지 않는다.
- `AppState`는 기존 회원/종목/장소/날씨 상태를 유지한다. 탭 번호는 제거하고 현재 라우트가 결정한다.
- `StatefulShellRoute.indexedStack`으로 네 탭 상태를 보존한다.
- 라우터 refresh는 `AppState.authChanges`만 구독한다. 회원가입 성공 알림과 pop의 경합을 방지한다.
- 로그인/회원가입은 공개, 운동 화면은 데모 로그인 이후 접근한다. 로그인 전 목적지는 내부 URL로만 보존한다.
- 종목 위치 화면은 `/sports/:sport/locations` 경로 매개변수를 받아 루트 Navigator에 표시한다.
- 웹은 기본 hash URL을 사용한다. 정적 서버에서 별도 rewrite 설정 없이 새로고침할 수 있다.
- 위치/선호 운동/회원/채팅은 기존과 같이 메모리다. URL이 있어도 새로고침으로 데이터가 복구되지는 않는다.
- API 인증, 날씨 API, LLM, 모바일 도메인 App Links 설정은 이번 과제 범위가 아니다.

## Stateful widgets 과제 확장 (2026-11-12)

- 기존 제출의 네 탭과 주소를 유지한다. 최근 기획한 5탭 UI 전체 구현과는 구분한다.
- `SportPickerSheet`는 `StatefulWidget`이다. `initState`에서 선택 초안을 복사하고 검색·체크 변경은 `setState`로 반영한다. 완료할 때만 선택값을 반환하며 닫기/취소는 원래 값을 유지한다. 검색 컨트롤러는 `dispose`한다.
- `/settings/notifications`는 로그인 보호 화면이다. 상단 알림 설정 버튼으로 진입하며 직접 링크도 지원한다.
- `NotificationSettingsScreen`은 저장된 불변 설정을 화면 초안으로 읽는다. 스위치·체크박스·시간 변경은 로컬 `setState`, 저장은 `AppState`가 맡는다. 저장하지 않은 변경은 뒤로 가기에서 확인한다.
- 알림 설정은 로그인 ID별 메모리 저장이다. 로그아웃 후 같은 ID로 돌아오면 같은 실행 세션에서 유지되지만 앱 재시작 시 초기화된다. 기기 알림 권한·실제 푸시·서버 스케줄러는 사용하지 않는다.
