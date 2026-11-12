# Routing 클래스 계약

- `AppRoutes`: 경로/이름 상수, 종목 한글명과 URL 식별자 변환, 안전한 내부 복귀 주소 검사.
- `createAppRouter(AppState, initialLocation?)`: 로그인 상태 redirect, 탭/상세 경로, 오류 화면 구성. initialLocation은 테스트 재현용이며 일반 실행은 플랫폼 주소를 따른다.
- `ExerciseAssistApp`: Provider에서 상태를 받고 라우터 생성/폐기. 테마 rebuild는 라우터 수명을 바꾸지 않는다.
- `HomeShell(StatefulNavigationShell)`: 현재 branch로 선택 탭을 표시하고 `goBranch`로 전환한다.
- `LoginScreen`: 로그인 성공 시 AppState 알림을 받아 라우터가 목적지로 이동한다. 회원가입 결과는 `pushNamed<String>`으로 받으며 await 뒤 mounted를 확인한다.
- `SignupScreen`: 이전 화면이 있으면 아이디를 pop으로 반환, 직접 URL 진입이면 로그인 경로로 복귀한다.
- `LocationScreen(sport)`: 검증된 종목만 받는다. 장소 선택 시 AppState 분석 대상을 바꾸고 분석 경로로 이동한다. 뒤로 가기만 하면 대상은 바뀌지 않는다.
- `RouteErrorScreen`: 알 수 없는 주소/종목 안내와 로그인 또는 운동 선택 복귀 버튼.
- `AppState`: 기존 데이터 동작 유지. `authChanges`는 로그인 ID 변경만 알리며 회원가입/테마 변경에 의한 라우트 재해석을 방지한다. tabIndex/goToTab 제거. URL 상태와 별도로 탭 번호를 저장하지 않는다.

## Stateful widgets 추가 계약

- `NotificationPreferences`: 불변 설정 값. 알림 종류와 시작 전 알림 시점은 수정 불가능한 Set으로 보관한다. `copyWith`, 값 동등성을 지원한다. 기기 권한 상태와는 별개다.
- `AppState.notificationPreferences`: 현재 로그인 ID의 저장 설정 또는 기본값. `saveNotificationPreferences(userId, value)`는 현재 ID가 일치할 때만 저장하며 성공 여부를 반환한다.
- `NotificationSettingsScreen`: `initState`에서 현재 사용자·저장값을 읽고 `_draft`를 만든다. master OFF는 세부 선호를 지우지 않고 컨트롤만 비활성화한다. 저장 시 초안이 기준값이 된다. 취소 시 공유 데이터는 변하지 않는다. 시간 선택과 이탈 확인의 await 이후 mounted를 검사한다.
- `SportPickerSheet(initialSelection)`: 초안 Set·검색 컨트롤러를 소유한다. 검색으로 숨겨진 종목도 선택을 유지한다. 완료 시 전체 종목의 고정 순서로 List를 반환한다.
