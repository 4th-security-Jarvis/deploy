# 4th-security-Jarvis 배포 가이드

사용자(개발자/운영자) 관점에서 로컬(또는 서버)에서 이 저장소를 클론하고 `docker-compose`로 전체 스택을 띄우기 위한 최소 설정과 체크포인트를 정리합니다.

## 개요

이 레포지토리는 Teleport 데몬과 백엔드(Go), 프론트엔드(React/Vite), 그리고 ELK(Elasticsearch / Logstash / Kibana)와 Teleport 이벤트 핸들러를 Docker Compose로 함께 띄우는 구성을 담고 있습니다.

주요 흐름:
- 저장소 클론
- `./.env.backend`에 환경 변수 설정
- GitHub에서 OAuth(Single Sign-On) 앱 등록 후 필요한 값 입력
- GCP Vertex AI (Gemini) 사용 설정 및 인증 정보 입력
- 필요한 Teleport 인증서/설정 파일을 `./teleport-daemon`에 준비
- `docker-compose up -d`로 서비스 시작

## 요구사항(사전 준비)

- Git
- Docker (데몬 실행)
- Docker Compose (v2 권장)
- GCP 프로젝트 및 서비스 계정
- GitHub 리포지터리/조직에 OAuth 앱 등록 권한

Windows PowerShell에서 실행할 것을 전제로 작성했습니다.

## 1. 저장소 클론

```powershell
git clone <repo-url>
cd deploy
```

## 2. 필수 파일과 디렉터리 준비

Compose 파일이 참조하는 호스트 경로들을 준비해야 합니다. 루트에 `teleport-daemon` 디렉터리가 있어야 합니다.

예:

```powershell
mkdir .\teleport-daemon\config -Force
mkdir .\teleport-daemon\data -Force
mkdir .\teleport-daemon\keys -Force
```

- `teleport-daemon/config/teleport.yaml` : Teleport 설정 파일 (예시는 repo 내에 있음). 사용 중인 설정으로 대체하세요.
- `teleport-daemon/keys/{fullchain.pem,privkey.pem}` : TLS 인증서
- `teleport-daemon/data` : Teleport가 사용하는 디렉터리(권장: 빈 디렉터리 준비).

> 실제 운영 환경에서는 LetsEncrypt 인증서나 사설 PKI를 사용해 적절한 인증서와 키를 넣으세요.

## 3. 환경 변수 구성 (`.env.backend`)

루트에 이미 `.env.backend` 템플릿이 있습니다. 아래 변수를 채우세요.

- JWT_SECRET_KEY: 안전한 랜덤 문자열
- GITHUB_CLIENT_ID: GitHub OAuth 앱의 Client ID
- GITHUB_CLIENT_SECRET: GitHub OAuth 앱의 Client Secret
- GITHUB_CALLBACK_URL: 예: `http://<your-host>:8080/callback` (백엔드 `api`의 콜백 엔드포인트)
- TELEPORT_AUDIT_LOG_PATH: `/var/lib/teleport/log` (Compose 내부 경로와 일치)
- GCP_PROJECT_ID: GCP 프로젝트 ID
- GCP_LOCATION: 예: `us-central1` (Vertex AI 리전)
- GEMINI_MODEL: 예: `models/text-bison@001` 또는 사용 중인 모델 이름
- TBOT_IDENTITY_FILE_PATH: Teleport tbot identity 파일 경로 (기본: `/var/lib/teleport/tbot/identity`)

참고: 백엔드는 `.env.backend`에 적힌 값을 사용해 tbot을 시작하고 Gemini API를 호출합니다. GCP 인증(서비스 계정 키 JSON)은 보통 `GOOGLE_APPLICATION_CREDENTIALS` 환경변수로 지정하거나 컨테이너에 마운트해서 제공해야 합니다. 이 프로젝트는 기본적으로 다음 중 한 가지 방식으로 GCP 인증을 기대합니다:

- (권장) 서비스 계정 키 JSON 파일을 생성하고 컨테이너에 마운트한 뒤 `GOOGLE_APPLICATION_CREDENTIALS` 환경 변수를 설정

예(개발용 .env.backend 항목 추가 제안):

```
GOOGLE_APPLICATION_CREDENTIALS=/secrets/gcp-sa.json
```

그리고 docker-compose에서 해당 파일을 마운트하세요.

## 4. GitHub SSO (OAuth 앱) 등록 요약

1. GitHub에서 OAuth 앱(또는 GitHub 앱)을 등록합니다.
2. 콜백 URL을 `GITHUB_CALLBACK_URL`에 맞춰 설정 (예: `http://localhost:8080/callback` 또는 실제 도메인)
3. 생성된 Client ID / Client Secret을 `.env.backend`에 입력

팁: 조직 단위 SSO를 원하면 GitHub 조직 설정과 OAuth 앱 권한을 확인하세요.

## 5. GCP Vertex AI (Gemini) 설정 요약

1. GCP 콘솔에서 Vertex AI API를 활성화
2. 모델(예: Gemini)을 사용 가능하도록 프로젝트/리전 확인
3. 서비스 계정 생성 -> 필요한 권한(예: Vertex AI User) 부여
4. 서비스 계정 키(JSON) 생성 후 로컬에 저장
5. 컨테이너에 이 파일을 마운트하거나 `GOOGLE_APPLICATION_CREDENTIALS` 환경변수로 경로를 알려줍니다.
6. `.env.backend`의 `GCP_PROJECT_ID`, `GCP_LOCATION`, `GEMINI_MODEL` 값을 채웁니다.

## 6. Teleport 관련(중요)

- `teleport-daemon/config/teleport.yaml` 파일을 준비하세요. (repo에 예시가 있으니 필요한 설정을 적용)
- Teleport가 tbot을 통해 identity 파일을 생성하는 흐름을 사용하므로 `tbot.yaml.template`이 백엔드 Dockerfile로 복사되어 `tbot`을 실행합니다.
- TBOT(봇) identity 파일 경로(`TBOT_IDENTITY_FILE_PATH`)가 백엔드 환경과 일치하는지 확인하세요.

## 7. 실행

개발/테스트 환경(백엔드 빌드 포함):

```powershell
docker-compose build backend frontend
docker-compose up -d

# 상태 확인
docker-compose ps
docker-compose logs --tail 200 backend
```

서비스가 시작되면 기본 엔드포인트 예시:
- 백엔드: http://localhost:8080
- 프론트엔드: http://localhost:3000
- Kibana: http://localhost:5601

## 8. 확인 및 문제해결 (트러블슈팅)

- docker compose가 마운트 오류(파일 또는 디렉터리 없음)를 보고하면 `teleport-daemon` 경로와 인증서 파일들이 있는지 확인하세요.
- 백엔드 빌드 실패: 로컬에 Go 빌드 도구나 네트워크 접근성이 문제일 수 있습니다. Docker 빌드 로그의 오류 메시지를 확인하세요.
- GitHub OAuth 문제: 콜백 URL이 정확히 일치해야 합니다. 포트, 스킴(http/https), 경로까지 일치해야 합니다.
- GCP 인증 문제: `Permission denied` 또는 `403` 에러가 나오면 서비스 계정 권한을 확인하세요.
- Teleport 통신 문제: Compose 네트워크상에서 `teleport-daemon:3025`로 연결 가능한지 `docker compose exec`로 테스트하세요.

## 9. 보안 참고

- `.env.backend`에는 민감한 값(클라이언트 시크릿, JWT 비밀, GCP 키 경로 등)이 있으므로 절대로 공개 저장소에 노출하지 마세요.
- 운영 환경에서는 TLS 인증서를 안전하게 보관하고 권한을 최소화하세요.

## 요구사항 점검표 (요약)

1. [ ] 저장소 클론
2. [ ] `teleport-daemon/{config,data,keys}` 준비 (teleport.yaml, certs)
3. [ ] `.env.backend`에 모든 필수 변수 채우기 (JWT, GitHub, GCP, TBOT 경로 등)
4. [ ] GitHub OAuth 앱 등록 및 Client ID/Secret 입력
5. [ ] GCP Vertex AI 활성화 + 서비스 계정 키 생성 및 컨테이너에 제공
6. [ ] `docker-compose up -d`로 스택 시작

---

해당 서비스는 보안을 위해 https통신을 요구합니다
https통신은 tls인증서가 필요하고 따라서 공인 ip와 도메인 네임이 필요하므로
이를 위한 환경이 갖춰진 클라우드 환경을 가정하고 설명합니다.

설치 가이드
sudo apt-get update

sudo apt-get install -y git,certbot,docker.io,docker-compose

git clone https://github.com/4th-security-Jarvis/deploy.git

cd deploy

git submodule update --init

.env파일 수정
(github sso, 조직생성)

sudo systemctl start docker

sudo systemctl enable docker

sudo chmod 666 /var/run/docker.sock

./start_script.sh

텔레포트 실행되면
컨테이너 접속 exec로

tctl create -f api-impersonator.yaml

tctl users add jarvis --roles=api-impersonator

tsh login --user=jarvis -o ./jarvis-service-identity --proxy localhost:3080 --ttl=14400 --overwrite

컨테이너 exit

docker cp teleport-daemon:/jarvis-service-identity
4th-security-Jarvis-BE/identityDir/

./start_script2.sh