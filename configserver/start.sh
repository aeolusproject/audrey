#!/bin/bash

export STORAGE_DIR="/tmp/audrey"
export INSTANCE_CONFIG_RNG="../schema/instance-config.rng"
export AEOLUS_CONFSERVER_VERSION="0.2.3"

cd src
if [ ! -d "log" ]; then
  mkdir log
fi

export APPLICATION_LOG="./log/configserver.log"
THIN_LOG="./log/thin.log"
RACK_ENV="development"
thin -l $THIN_LOG -R config.ru -e $RACK_ENV -p 4567 start $@
