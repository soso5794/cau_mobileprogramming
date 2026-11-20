# (Group Project) HTTP or File I/O · 제출 안내

## 제출할 것

과제 제목의 **HTTP or File I/O**에 맞춰 HTTP 통신을 구현했다. 제공된 안내에 HTTP와 File I/O를 모두 구현하라는 조건은 없으므로, 이 제출본은 실제 HTTPS GET을 핵심 근거로 제시한다. 별도 수업 내 추가 조건이 있다면 함께 확인한다.

| 요구사항 | 제출본에서 확인할 위치 |
|---|---|
| 이전 제출을 바탕으로 개선 | Stateful Widgets 제출 `668ea36` → 회원·캘린더·AI `977c6b8` → 이번 과제 브랜치 |
| 앱에 통신 기능 추가 | `lib/weather/weather_service.dart`: HTTPS GET, timeout, HTTP 상태 처리, JSON 파싱 |
| 응답을 앱에서 사용 | `lib/weather/live_weather_screen.dart`: 현재 날씨, 시간별 예보, 종목별 지수 |
| Stateful Widget | `initState`, `setState`, `FutureBuilder`: 로딩 → 성공/실패 → 재시도 |
| `lib/` | 저장소 루트에 포함 |
| `pubspec.yaml` | `http: ^1.6.0` 의존성 포함 |
| `assets/` (사용한 경우) | 별도 Flutter asset 미사용. 아이콘은 Material Icons 사용 |
| 공개 GitHub 저장소 | `soso5794/cau_mobileprogramming`, 2026-12-25까지 Public 유지 |

제출 기준: **기본 브랜치 `main`**

작업 브랜치 `assignment/http-communication_sangmin`은 개발 이력 확인용으로 보관한다.

제출 링크:
https://github.com/soso5794/cau_mobileprogramming

이번 HTTP 과제 코드는 기본 브랜치 main에 포함된다. 따라서 그룹 저장소 주소를 제출하면 README, lib/, pubspec.yaml과 과제 안내를 바로 확인할 수 있다.

## 기능 설명

대표 지점 4곳(중앙대 서울캠퍼스·잠실종합운동장·여의도 한강공원·부산 시민공원 주변)의 좌표로 기상 데이터를 조회한다. 사용자의 GPS·이메일·회원 프로필을 보내지 않는다. Open-Meteo의 현재 기상 모델 값과 앞으로 24시간의 시간별 예보를 표시한다.

농구·런닝·축구를 선택하면 같은 예보에 각 종목의 규칙을 적용한다. 시간 또는 종목만 변경할 때는 받은 데이터를 다시 계산하며 추가 HTTP 요청을 보내지 않는다. 장소 변경과 새로고침은 새로운 요청을 보낸다. 요청 중 중복 새로고침은 막지만 다른 장소 선택은 허용하며, 이전 장소의 늦은 응답이 현재 화면을 덮어쓰지 않도록 `FutureBuilder`의 Future 전환을 사용한다.

실패하면 임의의 날씨나 점수를 성공한 것처럼 보여주지 않는다. 연결 실패·12초 타임아웃·429·그 외 HTTP 오류·잘못된 JSON/단위/값·불완전한 시간별 배열을 오류로 처리하고 재시도 버튼을 제공한다.

## 코드 흐름

```text
홈의 구름 아이콘 / 내정보 → /me/weather
  → LiveWeatherScreen.initState()
  → OpenMeteoWeatherService.fetch(place)
  → http.Client.get(HTTPS URI).timeout(12초)
  → statusCode 확인 → jsonDecode → WeatherForecast.fromJson
  → FutureBuilder: 로딩 / 오류와 재시도 / 결과
  → ExerciseConditions.evaluate(종목, 선택한 시간의 예보)
```

| 파일 | 역할 |
|---|---|
| `lib/weather/weather_service.dart` | HTTP 요청, 상태 코드/타임아웃/연결/형식 오류 처리, 클라이언트 종료 |
| `lib/weather/weather_forecast.dart` | 장소·현재/시간별 모델, 숫자/단위/시간 검증, KST 표시, 지수와 근거 |
| `lib/weather/live_weather_screen.dart` | Stateful UI, 장소·종목·시간 선택, 새로고침, 로딩/오류/결과 |
| `lib/models/app_state.dart` | 서비스 주입 및 수명 관리 |
| `lib/routing/` | 기존 로그인 보호와 새 화면 경로 연결 |
| `android/app/src/main/AndroidManifest.xml` | INTERNET 권한 (기존 설정 유지) |
| `test/weather_service_test.dart` | HTTP 계약, JSON 검증, 타임아웃/오류, 지수 경계 테스트 |
| `test/live_weather_test.dart` | UI 전환, 재시도, 오래된 응답 무시, 화면 종료, 접근성, 실제 경로 테스트 |
| `tool/check_weather_api.dart` | 실제 앱과 같은 HTTP/파서로 공개 API 연결 검증 |

## API와 데이터 처리

`GET https://api.open-meteo.com/v1/forecast`

- `latitude`, `longitude`: 선택한 대표 지점 좌표
- `current`: temperature_2m, relative_humidity_2m, precipitation, weather_code, wind_speed_10m
- `hourly`: 위 값 및 precipitation_probability
- `forecast_hours=24`, `timezone=Asia/Seoul`, `timeformat=unixtime`
- 단위: 기온 Celsius, 풍속 m/s, 강수량 mm

Unix 시간을 UTC instant로 파싱한 뒤 표시할 때만 UTC+9를 적용한다. 기기 시간대가 달라도 한국의 날짜·시간이 표시된다. 현재 카드에는 현재 기온·습도·풍속을 표시하며 **환경지수는 선택한 시간의 시간별 예보로 계산**한다. 현재 강수량과 시간당 예보 강수량을 섞어 계산하지 않는다.

Open-Meteo API 문서: https://open-meteo.com/en/docs

Flutter HTTP 구현 가이드: https://docs.flutter.dev/cookbook/networking/fetch-data

데이터 출처: Open-Meteo, CC BY 4.0. 앱에도 출처를 표시한다.

## 지수 규칙과 범위

공식 기상/의학 지수가 아닌 수업용 규칙이다. 100점에서 아래 값을 차감하고 0~100으로 제한한다.

| 조건 | 농구 | 런닝·축구 |
|---|---|---|
| 기온 | `abs(기온 - 20) × 2` | `abs(기온 - 18) × 2` |
| 습도 | 65% 초과분 × 0.4 | 동일 |
| 바람 | 풍속(m/s) × 3 | 풍속(m/s) × 2 |
| 시간당 강수 | 강수량(mm) × 18 | 강수량(mm) × 10 |
| 강수확률 | 확률(%) × 0.1 | 동일 |

뇌우 코드·눈/결빙성 강수 코드, 풍속 15m/s 이상, 기온 35°C 이상 또는 -10°C 이하이면 최대 20점으로 제한한다. 이 기준은 프로토타입 정책이며 안전 판정 기준으로 검증된 것은 아니다. 미세먼지, 운영 시간, 야간 조명, 코트 점유/예약, 바닥 상태는 반영하지 않는다. 미래 시간 중 최고 점수는 **상대적인 비교 결과**로 표시하며 실제 운동 가능성을 보장하지 않는다.

## 실행 및 2~3분 시연

```sh
git clone https://github.com/soso5794/cau_mobileprogramming.git
cd cau_mobileprogramming
flutter pub get
flutter run -d chrome --web-port 7363
```

검증 환경: Flutter 3.47.4 / Dart 3.13.3. 지원 플랫폼: Web, Android.

1. **DEMO 계정으로 둘러보기 → 농구 계정**으로 진입한다. 별도 가입 불필요.
2. 홈 상단 구름 아이콘 또는 내정보의 **실시간 운동 날씨**를 누른다.
3. 로딩 후 현재 날씨·기준 시각·조회 완료 시각을 확인한다.
4. 장소를 잠실/부산으로 바꾸고 실제 새 HTTP 요청 결과를 확인한다.
5. 런닝/축구 및 예보 시간을 선택하고 **지수 산정 이유**를 펼친다.
6. 네트워크를 끊고 새로고침 → 오류 → 다시 연결하고 **다시 시도**한다. 브라우저 DevTools에서 Offline을 사용할 수도 있다.
7. 브라우저 Network 탭에서 `api.open-meteo.com/v1/forecast` GET/200/JSON 응답을 제시한다.

공개 API의 서비스 장애·요청 제한이 있으면 재시도하고 테스트 결과를 함께 확인한다. 키나 자체 서버는 필요하지 않다. 기존 AI 채팅은 별도 OpenAI 설정이 필요한 기능이며 이번 과제의 필수 시연 경로가 아니다.

## 제출란에 붙여 넣을 설명

> 이전 Stateful Widgets 앱을 확장해 Open-Meteo 날씨 API에 HTTPS GET 요청을 보내는 기능을 구현했습니다. JSON 응답을 모델로 변환하여 현재 날씨와 24시간 예보를 표시하고, 종목·시간별 운동 환경지수를 계산합니다. 로딩, 오류, 타임아웃, 재시도와 장소 변경을 지원합니다. lib/와 pubspec.yaml을 포함했으며 별도 assets는 사용하지 않았습니다. 실행 후 DEMO 계정 → 홈의 구름 아이콘에서 확인할 수 있습니다. 기본 브랜치 main에 과제 코드를 포함했으며 저장소는 12월 25일까지 공개 상태로 유지합니다.
