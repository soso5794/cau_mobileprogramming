# 이번 주 과제: Routing screens

## 요구사항 해석

기존 제출물을 기반으로 화면 라우팅을 추가하는 진도 확인 과제다. 화면은 수정할 수 있다.
제출은 팀 GitHub 저장소 URL이며 `lib/`, `pubspec.yaml`, 사용했다면 `assets/`를 포함한다.
저장소는 2026년 12월 25일까지 공개 상태를 유지해야 한다. assets를 사용하지 않아 빈 폴더를 추가하지 않았다.

## 작업 기준과 이전 앱 비교

- 기준 저장소: https://github.com/soso5794/cau_mobileprogramming
- 기준 커밋: `268161653d878557a2ff8940f007ad40433fcabc` (main)
- 작업 브랜치: `assignment/routing-screens`
- 운동 Assist: 6종목, 종목별 장소 입력, 주간 운동지수, 날씨 수동 조절, 데모 로그인, AI 채팅 예시.
- 별도 OUTIME exerciseapp: 3종목, 시간·코스 선택, 저장 계획·반복 루틴, 워치 전송 시뮬레이션, MVVM/Repository와 운영 웹·서버.
- 공통: Flutter/한국어/4탭/테마/샘플 날씨/사용자 앱 메모리 저장. 두 앱은 기능과 코드 구조가 다르다.
- 이번 변경은 운동 Assist의 기존 화면/Provider 구조에 적용했다. OUTIME 파일을 가져오거나 수정하지 않았다.

## 이전 제출 대비 변경

기존에는 로그인/회원가입/홈만 named route였고 네 탭은 AppState.tabIndex로 전환했다.
이번에는 `MaterialApp.router`와 `go_router`로 화면 주소를 관리하고 탭/상세/오류 경로를 구성했다.

| 주소 (웹에서는 # 뒤) | 화면 | 동작 |
|---|---|---|
| `/login` | 로그인 | 데모 로그인, 목적지 복귀 |
| `/signup` | 회원가입 | push/pop으로 아이디 반환, 직접 진입 시 로그인 복귀 |
| `/sports` | 운동선택 | 선호 운동 편집, 종목 위치 화면 진입 |
| `/sports/:sport/locations` | 위치 입력 | 종목 경로 매개변수, 장소 선택 → 분석 |
| `/plan` | Week Plan | 요일별 적합도·추천 일정 |
| `/analysis` | 운동분석 | 선택한 종목/장소 분석, 대상 없으면 선택 안내 |
| `/ai` | AI 운동 도우미 | 채팅 예시, 탭 전환 시 입력 유지 |
| `/`, `/home` | 이전 주소 호환 | `/sports`로 연결 (미로그인 시 로그인) |
| 그 외 / 알 수 없는 종목 | 화면 안내 | 로그인/운동 선택으로 복귀 버튼 |

종목 식별자: `basketball`, `running`, `sailing`, `hiking`, `kayaking`, `cycling`.
네 탭은 StatefulShellRoute.indexedStack을 사용하여 탭별 화면 상태를 보존한다.
위치 상세는 운동선택 위에 쌓이므로 앱/시스템 뒤로 가기로 운동선택에 돌아간다.
로그인 전 요청 주소는 `from` 쿼리에 보관하며 외부 URL/인증 화면으로의 복귀는 허용하지 않는다.
회원가입 화면에서 등록 성공/취소와 직접 URL 진입을 구분한다.

## 실행 및 시연

Flutter 3.44.0+, Dart 3.12.0+가 필요하다 (`go_router 18.1.2` 요구 버전).

```sh
flutter pub get
flutter run -d chrome
```

1. 임의의 비어 있지 않은 아이디·비밀번호로 데모 로그인한다.
2. 운동선택 → 종목 추가 → 농구 → 장소 입력 → 장소 선택 → 운동분석.
3. Plan / 운동분석 / AI 탭을 누르며 URL과 선택 탭이 일치하는지 확인한다.
4. AI에 입력 중인 문장을 두고 다른 탭에 갔다가 돌아와 입력 유지를 확인한다.
5. 로그아웃한 다음 `/#/sports/running/locations`로 접속한다. 로그인 후 런닝 위치 화면으로 돌아온다.
6. 위치 화면의 뒤로 가기를 눌러 운동선택에 돌아온다.
7. `/#/signup` 직접 접속, 가입/취소 복귀와 `/#/missing-screen` 오류 안내를 확인한다.
8. 로그인 상태에서 브라우저 뒤로/앞으로를 누르면 주소에 맞는 탭으로 이동한다. 로그아웃 후 보호 화면 재접근은 로그인으로 보낸다.

`flutter build web` 후 정적 서버에서도 확인할 수 있다.

```sh
python3 -m http.server 7361 --bind 127.0.0.1 --directory build/web
```

웹 주소 예: `http://127.0.0.1:7361/#/plan`. 기본 hash URL을 유지하여 별도 서버 rewrite가 필요 없다.

## 제출 전 확인

- `lib/`, `pubspec.yaml`, 재현용 `pubspec.lock`, `test/`, 설명 문서를 팀 저장소에 반영한다.
- 기존 저장소는 확인 시 public이었다. 12월 25일까지 공개 상태 유지는 저장소 운영자가 관리해야 한다.
- 원격 반영/과제 시스템 제출 여부는 실제 수행 결과와 구분한다. 로컬 파일 준비만으로 제출 완료가 아니다.
- 검증 범위와 미검증 내용: [VALIDATION.md](VALIDATION.md).

## 범위

로그인은 기존 데모 로직이며 서버 인증이 아니다. 실제 날씨/AI/지도 서비스는 연결하지 않았다.
새로고침하면 로그인/등록한 장소/선호 운동/채팅은 초기화된다. 보호 URL은 로그인 후 다시 열 수 있으나 분석 대상 데이터는 다시 선택해야 한다.
모바일 HTTPS App Links/Universal Links는 도메인 등록이 필요한 별도 작업이며 이번에는 앱 내부 이동과 웹 URL을 구현했다.

공식 참고: [go_router](https://pub.dev/packages/go_router), [StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html).
