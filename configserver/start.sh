#!/bin/bash
#
#   Copyright [2011] [Red Hat, Inc.]
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#  limitations under the License.
#

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
