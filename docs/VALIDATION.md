# 과제 검증 기록

## Stateful widgets — 2026-11-12

기준: main `90bf6e83a099535d9216a7e82a97f37964d1b37f`.
브랜치: `assignment/stateful-widgets`.
환경: macOS arm64, Flutter 3.47.4, Dart 3.13.3.

| 실제 실행 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 19개 통과: 기존 라우팅 11 + 새 위젯 7 + 상태 모델 1 |
| `flutter build web` | release 웹 빌드 성공, Wasm dry run 성공 |
| `git diff --check` | 통과 |
| GitHub 저장소 메타데이터 | 공개(public), 연결 계정 push 권한 확인 |

새 테스트는 알림 초안/저장/재진입, 시스템 뒤로 가기와 변경 폐기,
전체 알림 비활성화 시 하위 선택 보존, 알림 시점 저장, 로그인 후 직접 주소 복귀,
시간 선택창 취소와 방해금지 저장, 종목 검색 중 숨겨진 선택 보존 및 취소/완료,
계정별 알림 설정 분리·불변성을 확인한다.
운동 선택창은 360×640, 키보드 inset 280, 글꼴 150%, 다크 테마로 레이아웃 예외도 확인했다.

실패했던 테스트의 원인은 아직 생성되지 않은 스크롤 목록 항목을 찾거나 스크롤 후
레이아웃 갱신 전에 탭한 것이었다. 스크롤 탐색과 프레임 대기를 추가한 뒤 전체 테스트가 통과했다.

이번 변경의 Android/iOS 실기기 실행과 실제 브라우저 조작은 확인하지 않았다.
웹 빌드 성공은 실기기 검증과 구분한다. 알림 발송·영구 저장은 범위 밖이며,
시간 선택값 변경의 모든 조합과 모든 화면의 접근성 대응을 검증한 것은 아니다.

## 이전 Routing screens 검증 기록

검증일: 2026-11-03 (Asia/Seoul).
대상: GitHub main `268161653d878557a2ff8940f007ad40433fcabc`에서 분기한 `assignment/routing-screens`.
환경: macOS arm64, Flutter 3.47.4, Dart 3.13.3, go_router 18.1.2.

## 실제 실행

| 명령/검사 | 결과 |
|---|---|
| `flutter pub get` | 성공 |
| `flutter analyze` | No issues found |
| `flutter test` | 라우팅 위젯 테스트 11개 통과 |
| `flutter build web` | release 웹 빌드 성공, Wasm dry run 성공 |
| `git diff --check` | 통과 |
| 로컬 HTTP 서버 | `127.0.0.1:7361`, HTTP 200 및 앱 리소스 응답 확인 |
| Chrome 데스크톱 | 로그인 한국어 화면 렌더링, `/plan` 직접 진입 시 로그인 redirect와 로그인 후 Plan 복귀, AI 탭의 `/ai` URL, 브라우저 뒤로 가기 시 `/plan` 복귀 확인 |

## 자동 테스트로 확인한 사용자 동작

1. 로그인 → 네 탭의 URL/화면 일치, AI 입력 보존, 테마 변경 시 라우터 유지.
2. 보호 화면 요청 → 회원가입 → 아이디 반환 → 로그인 → 원래 Plan으로 이동.
3. 회원가입 취소 후 로그인 입력 유지.
4. `/signup` 직접 진입 후 등록 성공/로그인 복귀와 AI 목적지 유지.
5. 운동선택 → 종목 위치 경로, 시스템 뒤로 가기, 장소 등록·선택 → 분석 대상/선택 탭 일치.
6. 보호된 위치 상세 직접 진입 → 로그인 → 종목 매개변수 유지, 뒤로 가기로 운동선택 복귀.
7. AI 응답 대기 중 로그아웃, 늦은 응답 무시, 보호 주소 재요청 시 로그인 표시.
8. 플랫폼 라우트 정보 `/plan` 수신 시 해당 탭 선택.
9. 존재하지 않는 주소 오류 안내·복구.
10. 지원하지 않는 종목 URL 오류 안내·복구.
11. 외부 URL을 로그인 복귀 대상으로 지정해도 앱의 운동선택으로 이동.

위젯 테스트 화면 크기는 390×844 논리 픽셀이다. 플랫폼 URL 이벤트 검증은 실제 브라우저 history 테스트와 구분한다.

## 확인 후 수정한 문제

- AppState 전체 변경을 라우터 refresh에 연결하면 회원가입 register 알림과 pop이 경합하여 회원가입 화면이 다시 나타났다. 로그인 ID 전용 `authChanges`를 분리하고 회원가입 결과 반환 회귀 테스트를 통과시켰다.
- 기존 운동분석 화면의 날짜 Row가 좁은 화면에서 22px 넘쳤다. 날짜 Text를 Flexible로 감싸 줄바꿈 가능하게 수정하고 장소→분석 흐름을 재검증했다.
- strict analysis에 맞춰 기존 AI 예시 지연의 Future<void> 타입을 명시했다.

## 미검증 및 범위 제한

- Chrome에서 브라우저 뒤로 가기까지 확인한 뒤 CUA 연결이 `noWindowsAvailable`/`timeoutReached`로 끊겼다. 이후 실제 앞으로 가기와 새로고침을 통한 복귀는 미검증이다.
- Android/iOS 빌드, 에뮬레이터/실기기, 모바일 도메인 App Links/Universal Links는 실행하지 않았다.
- 모든 화면의 360dp/200% 글꼴/스크린리더 대응, 성능/보안 검증은 이번 과제 검증 범위에 포함하지 않는다.
- 로그인은 기존 메모리 데모 인증이다. 서버 보안/실제 계정 로그인이 아니다. 재시작/새로고침 시 사용자 상태는 초기화된다.
- 실제 날씨 API/LLM/지도/영구 저장은 추가하지 않았다.
- 최초 업로드 시도에서는 `git push --dry-run origin HEAD:refs/heads/assignment/routing-screens`가 `Permission denied to CircusHan` / HTTP 403으로 실패했다. 이후 권한 부여 후 업로드 결과는 아래에 기록한다.
- 원격 main을 작업 후 다시 조회했으며 기준 커밋과 동일했다. 로컬 구현 완료와 원격 제출 완료는 별개다.

## 2026-11-03 권한 부여 후 GitHub 업로드

- 연결된 저장소 권한 `pull=true`, `push=true`, 공개 상태 `public`을 확인했다.
- `git fetch origin` 후 원격 main에 추가 커밋이 없음을 확인했다.
- `git push -u origin assignment/routing-screens` 성공. 최초 업로드 HEAD `d162ddb2cf3f459d7450ccdd56f683bd4c324a72`가 원격 브랜치와 일치했다.
- `lib/`, `pubspec.yaml`, `pubspec.lock`, 테스트/문서를 포함한다. `build/`, `.dart_tool/`은 추적 및 업로드 대상에 없다.
- [과제 브랜치](https://github.com/soso5794/cau_mobileprogramming/tree/assignment/routing-screens) · [main과 비교](https://github.com/soso5794/cau_mobileprogramming/compare/main...assignment/routing-screens).
- PR #1 생성 및 main 병합이 완료되었다. eclass 제출 여부는 별도로 확인해야 한다.
- 소스/의존성은 검증 이후 변경하지 않았다. 이번 후속 변경은 이 업로드 기록뿐이므로 Flutter 검증을 재실행하지 않았다.
