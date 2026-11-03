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
