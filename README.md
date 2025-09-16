# 4th-security-Jarvis 배포 가이드

개발자 관점에서 로컬에서 이 저장소를 클론하고 `docker-compose`로 전체 스택을 띄우기 위한 최소 설정과 체크포인트를 정리합니다.
서비스용이 아니므로 tls인증서와 같은 보안 옵션들이 제거되어있으며 오직 기능수정후 실제환경에서 테스트해보기 위한 설치가이드입니다.

## 개요

이 레포지토리는 Teleport 데몬과 백엔드(Go), 프론트엔드(React/Vite), 그리고 ELK(Elasticsearch / Logstash / Kibana)와 Teleport 이벤트 핸들러를 Docker Compose로 함께 띄우는 구성을 담고 있습니다.


## GitHub SSO (OAuth 앱) 등록 요약

1. GitHub에서 OAuth 앱(또는 GitHub 앱)을 등록합니다.
2. 콜백 URL을 `GITHUB_CALLBACK_URL`에 맞춰 설정 (예: `http://localhost:8080/callback`)
3. 생성된 Client ID / Client Secret을 `.env`에 입력

팁: 조직 단위 SSO를 원하면 GitHub 조직 설정과 OAuth 앱 권한을 확인하세요.


## 설치 가이드
sudo apt-get update

sudo apt-get install -y git,docker.io,docker-compose

git clone -b localdeploy https://github.com/4th-security-Jarvis/deploy.git

cd deploy

git submodule update --init

.env파일 수정
(github sso, 조직생성)

sudo systemctl start docker

sudo systemctl enable docker

sudo chmod 666 /var/run/docker.sock

./start_script.sh

docker exec -it teleport-daemon sh

tctl create -f ./etc/teleport/api-impersonator.yaml

tctl users add jarvis --roles=api-impersonator
여기에서 url의 도메인 부분을 localhost로 수정해야함

tsh login --user=jarvis -o ./etc/teleport/jarvis-service-identity --proxy localhost:3080 --ttl=14400 --overwrite --insecure

컨테이너 exit

./start_script2.sh
