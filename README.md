# VALORANT CUSTOM — Realtime

## Supabase 연결 설정
1. https://supabase.com 에서 새 프로젝트를 만듭니다.
2. SQL Editor에서 `supabase-schema.sql` 전체를 실행합니다.
3. Project Settings → API에서 Project URL과 anon/public key를 복사합니다.
4. `config.js`의 `YOUR_SUPABASE_PROJECT_URL`, `YOUR_SUPABASE_ANON_PUBLIC_KEY`를 교체합니다.
   - `service_role` key는 절대 사용하거나 공유하지 마세요.
5. `index.html`, `config.js`를 같은 폴더에 두고 정적 호스팅(Vercel, Netlify 등)에 배포합니다.
6. 배포 URL을 친구들에게 공유합니다.

## 기능
- 방 생성/참가, 6자리 코드
- 초대 링크 복사
- 최대 10명 참가
- 방장 서버 검증(비밀 토큰의 SHA-256 해시 저장)
- 방장만 팀 추첨/맵 추첨/참가자 추가/초기화
- Supabase Realtime으로 모든 접속자의 화면 갱신

## 주의
- 참가자 목록과 추첨 결과는 방 코드로 조회 가능한 공개 룸 정보입니다. 민감한 개인정보를 입력하지 마세요.
- 방장 토큰은 방을 만든 브라우저의 세션 메모리에만 보관됩니다. 방장 브라우저를 새로고침하거나 닫으면 그 방의 방장 권한을 잃습니다. 현재 버전은 방장 권한 복구 기능이 없습니다.
- 이 starter는 익명 참가를 허용합니다. 악의적인 대량 방 생성/참가 방지를 위해 실제 공개 서비스 전에는 CAPTCHA/rate limit을 추가하는 것이 좋습니다.
- Supabase의 Realtime publication에 이미 rooms가 등록되어 있으면 SQL의 publication 추가 문장이 중복 오류를 낼 수 있습니다. 그 경우 해당 문장만 건너뛰세요.
