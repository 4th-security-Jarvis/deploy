#!/bin/bash
set -e

envsubst < ./teleport-daemon/config/teleport.yaml.template > ./teleport-daemon/config/teleport.yaml
//일단 손수 수정하는걸로 나중에 수정

# 텔레포트 데몬으로 시작
docker-compose up -d teleport-daemon