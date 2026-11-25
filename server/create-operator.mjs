import {existsSync, writeFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {hashOperatorPassword, operatorEmail} from './admin-auth.mjs';
const accountFile = new URL('./.operator-account.json', import.meta.url);
const loginFile = new URL('./.operator-login.txt', import.meta.url);
if (existsSync(accountFile) || existsSync(loginFile)) {
  console.log('운영자 설정 파일이 이미 있습니다. 기존 계정을 덮어쓰지 않았습니다.');
  process.exitCode = 1;
} else {
  const password = randomBytes(24).toString('base64url');
  const account = await hashOperatorPassword(password);
  writeFileSync(accountFile, JSON.stringify(account), {mode: 0o600, flag: 'wx'});
  writeFileSync(loginFile, `운동 Assist 로컬 운영자 로그인\n이메일: ${operatorEmail}\n비밀번호: ${password}\n\n서버 실행 후 앱의 운영자 로그인에서 입력하세요. 이 파일을 GitHub/노션/채팅에 공유하지 마세요.\n`, {mode: 0o600, flag: 'wx'});
  console.log('운영자 1개를 생성했습니다. 로그인 정보: server/.operator-login.txt (Git 제외)');
}
