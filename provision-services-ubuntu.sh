#!/usr/bin/env bash

set -exu

REPLICATED_VERSION="2.10.3"
DOCKER_VERSION="17.03.2"
UNAME="$(uname -r)"
DEBIAN_FRONTEND=noninteractive

is_xenial(){
  [ "$(cut -d'.' -f1 <<< $UNAME)" = "4" ] && return 0 || return 1
}

guess_private_ip(){
  INET="eth0"
  is_xenial && INET="ens3"
  /sbin/ifconfig $INET | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'
}

write_config(){
  config_dir=/var/lib/replicated/circle-config
  mkdir -p "$config_dir"

  echo "${HTTP_PROXY:-}" > $config_dir/http_proxy
  echo "${HTTPS_PROXY:-}" > $config_dir/https_proxy
  echo "${NO_PROXY:-}" > $config_dir/no_proxy
}

run_installer(){
  echo "-------------------------------------------"
  echo "     Performing System Updates"
  echo "-------------------------------------------"
  apt-get update && apt-get -y upgrade

  echo "--------------------------------------------"
  echo "       Finding Private IP"
  echo "--------------------------------------------"


  PRIVATE_IP=${PRIVATE_IP:-$(guess_private_ip)}
  export PRIVATE_IP

  echo "Using address: ${PRIVATE_IP}"

  echo "--------------------------------------"
  echo "  Upgrading Kernel & Installing Docker"
  echo "--------------------------------------"
  if is_xenial; then
    apt-get install -y "linux-image-${UNAME}"
  else
    apt-get install -y "linux-image-extra-$(uname -r)" linux-image-extra-virtual
  fi
  apt-get install -y apt-transport-https ca-certificates curl
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  apt-get update
  apt-get -y install "docker-ce=${DOCKER_VERSION}~ce-0~ubuntu-$(lsb_release -cs)" cgmanager

  echo "--------------------------------------------"
  echo "          Downloading Replicated"
  echo "--------------------------------------------"
  curl -sSk -o /tmp/get_replicated.sh "https://get.replicated.com/docker?replicated_tag=$REPLICATED_VERSION&replicated_ui_tag=$REPLICATED_VERSION&replicated_operator_tag=$REPLICATED_VERSION"

  echo "--------------------------------------------"
  echo "          Installing Replicated"
  echo "--------------------------------------------"

  bash /tmp/get_replicated.sh local-address="$PRIVATE_IP" no-proxy no-docker
}

run_installer
write_config
