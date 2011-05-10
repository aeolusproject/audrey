#!/bin/bash

export STORAGE_DIR="/tmp/audrey"
export INSTANCE_CONFIG_RNG="../schema/instance-config.rng"

cd src


thin -R config.ru -p 4567 start
