#!/bin/bash

export STORAGE_DIR="/tmp/audrey"
export INSTANCE_CONFIG_RNG="../schema/instance-config.rng"
export AEOLUS_CONFSERVER_VERSION="0.2.3"

cd src


thin -R config.ru -p 4567 start $@
