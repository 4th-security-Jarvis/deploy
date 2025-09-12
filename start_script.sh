#!/bin/bash
set -e

export $(grep -v '^#' .env | xargs)
envsubst < /teleport-daemon/teleport.yaml.template > /teleport-daemon/teleport.yaml

# 텔레포트 데몬으로 시작
docker-compose up -d teleport-daemon