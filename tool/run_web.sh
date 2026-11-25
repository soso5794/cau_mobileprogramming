#!/usr/bin/env bash
set -euo pipefail

# Serve a stable origin without creating a temporary Chrome profile.
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
printf '%s\n' \
  '운동 Assist: http://localhost:7363' \
  '서버 준비 후 평소 사용하는 Chrome 프로필에서 위 주소를 여세요.' \
  '같은 프로필과 주소를 사용하면 회원정보가 유지됩니다. 시크릿 창은 사용하지 마세요.' \
  '이미 실행 중이면 기존 터미널에서 종료한 뒤 다시 실행하세요. 다른 포트로 바꾸지 마세요.'
exec flutter run -d web-server --web-hostname localhost --web-port 7363
