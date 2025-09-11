#!/bin/bash
set -e

sudo apt-get update
sudo apt-get install -y docker.io docker-compose

sudo systemctl start docker
sudo systemctl enable docker

# 텔레포트 데몬으로 시작
docker-compose up -d teleport-daemon

# 텔레포트 서비스 HTTP(3080) 준비 대기 (curl 또는 nc 등 활용)
until curl -s http://localhost:3080 > /dev/null; do
  echo "Waiting for teleport-daemon to be ready..."
  sleep 2
done

# 텔레포트 역할 생성
if ! docker exec teleport-daemon tctl get role teleport-event-handler > /dev/null 2>&1; then
  docker exec teleport-daemon tctl create -f event-listen/plugin/teleport-event-handler-role.yaml
  echo "Role teleport-event-handler created."
else
  echo "Role teleport-event-handler already exists."
fi

# 텔레포트에 bot 삭제 및 토큰 발급
docker exec teleport-daemon tctl bots rm jarvis-bot || true
JOIN_TOKEN=$(docker exec teleport-daemon tctl bots add jarvis-bot --roles=editor,teleport-event-handler --ttl=5m | grep 'The bot token: ' | awk '{print $4}')

if [ -z "$JOIN_TOKEN" ]; then
  echo "Error: Failed to generate or extract bot join token."
  exit 1
fi

echo "JOIN_TOKEN=$JOIN_TOKEN" > .env

# 백엔드 서비스 시작
docker-compose up -d backend

# 백엔드 코드에서 사용되는 마스터 유저 생성은 사용자가 직접하면 된다.

# ELK + plubin 서비스 시작
# 해보고 서비스 연결이 잘 안되면 health check 추가해야함
docker-compose up -d logstash elasticsearch kibana tp-event-handler

# 프론트 서비스 시작

docker-compose up -d frontend