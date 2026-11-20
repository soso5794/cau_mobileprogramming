# AI 운동 도우미 서버

Flutter → 이 로컬 서버 → OpenAI Responses API 순서로 연결합니다. 기본 모델은 `gpt-4.1-mini`이며 `OPENAI_MODEL`로 변경할 수 있습니다. API 키는 서버 환경변수에서만 읽습니다.

## 설정과 실행

Node.js 22 이상이 필요합니다. 외부 npm 패키지는 사용하지 않습니다.

```sh
cd exercise-assist-team/server
# .env가 없는 경우에만 복사하세요. 기존 키를 덮어쓰지 마세요.
cp -n .env.example .env
# 편집기에서 .env의 OPENAI_API_KEY= 뒤에 키 입력
npm start
```

이미 작업 폴더에는 빈 `.env`를 준비했습니다. **키를 Flutter 코드, --dart-define, 채팅, GitHub에 넣지 마세요.** `.env`는 Git과 공유 ZIP에서 제외합니다. 키 설정 후 서버를 재시작하세요.

```sh
curl http://127.0.0.1:8787/health
# configured: true면 키 문자열이 설정된 상태입니다. 키 유효성/결제/모델 접근 권한까지 확인한 것은 아닙니다.
```

앱 실행은 별도 터미널에서 진행합니다.

```sh
cd exercise-assist-team
flutter pub get
flutter run -d chrome --web-port=7362
# Android 에뮬레이터는 10.0.2.2:8787을 기본 사용합니다.
flutter run -d emulator-5554
```

서버 포트를 바꾸거나 HTTPS 프록시를 사용하는 경우:

```sh
flutter run -d chrome --dart-define=AI_BASE_URL=http://127.0.0.1:8788
```

앱의 **내정보 → AI 운동 도우미**에서 질문을 보내면 실제 API를 호출합니다. 유효한 키와 API 사용 가능 상태가 필요하며 요금이 발생할 수 있습니다. 현재 사용자는 키 설정을 나중에 하기로 했으므로 실제 OpenAI 응답/요금은 검증하지 않았습니다. 키가 없으면 명확한 설정 안내를 반환하며 더미 답변으로 대체하지 않습니다.

## 지원 범위

- 최근 19개 메시지(사용자 최대 2,000자/메시지), 대화 맥락, 로딩/재시도/새 대화.
- 질문과 최근 대화만 전송. 회원 프로필, 이메일, 캘린더 일정은 자동 전송하지 않습니다.
- OpenAI 요청에 `store: false`를 전달합니다. 이 값은 모든 제공업체 로그 보관을 없앤다는 의미가 아닙니다.
- 서버는 대화를 파일이나 DB에 저장하지 않습니다. 앱 대화는 메모리에만 있으며 로그아웃 시 제거됩니다.
- 45초 타임아웃, 분당 20회/동시 2회 제한, 입력 길이 제한, 외부 Origin/Host 거부. 실패 시 API 키나 upstream 원문 오류를 앱에 노출하지 않습니다.
- 로컬 시연 서버이며 **127.0.0.1에만 바인딩**합니다. 공개 배포용 사용자 인증·사용자별 과금 제한은 없습니다. 공개 서비스로 운영하려면 서버 인증과 HTTPS/배포 구성이 별도로 필요합니다.
- 웹과 Android 에뮬레이터 기준. 실물 휴대폰에서 PC의 localhost에 바로 연결할 수는 없습니다. HTTPS 서버 배포/인증 후 해당 주소를 설정하세요.
- Android는 debug 빌드에서만 `10.0.2.2`, `127.0.0.1`, `localhost`에 대한 개발용 HTTP를 허용합니다. release는 HTTPS를 사용하세요.
- 실시간 날씨/코트 점유/모집 데이터를 조회하거나 캘린더를 자동 변경하는 도구는 이번 연결에 포함하지 않았습니다.

## 검증

```sh
npm test
# 앱 루트에서
flutter analyze
flutter test
```

서버 테스트는 제공업체 요청을 대역으로 검증하며 API 비용을 발생시키지 않습니다. 실제 유료 API 응답 확인과 구분합니다.

구현 기준: [OpenAI Responses API](https://developers.openai.com/api/reference/resources/responses/methods/create), [GPT-4.1 mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini).
