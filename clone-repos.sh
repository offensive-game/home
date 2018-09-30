#!/bin/bash
set -e

appNames=("web-client" "demo-server" "proxy" "server" "db" "go-server")

for appName in "${appNames[@]}"
do
  if [ ! -d "apps/${appName}/.git" ]
  then
    echo "${INFO}Cloning $appName"
    git clone git@github.com:offensive-game/${appName}.git apps/${appName}
  fi
done
