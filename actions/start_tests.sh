#!/bin/bash

#    Copyright 2014 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

#
# This script creates a master node for the product, launches its installation,
# and waits for its completion
#

source $1
source functions/resources.sh
env_ip=$2

prepare_config_and_start_tests() {
    echo "Start tests"
    cp $savanna_test_settings sahara/sahara/tests/integration/configs/itest.conf &&
    sed -i "s/OS_AUTH_URL =.*/OS_AUTH_URL = \"http:\/\/$env_ip:5000\/v2.0\"/" sahara/sahara/tests/integration/configs/itest.conf &&
    sed -i "s/SAHARA_HOST =.*/SAHARA_HOST = \'$env_ip\'/" sahara/sahara/tests/integration/configs/itest.conf &&
    cd sahara && tox -e integration -- --concurrency=1 >> $OLDPWD/$private_bridge-savanna-tests.log
    check_return_code_after_command_execution $? "sahara tests failure"
    cd $OLDPWD
    echo_ok
}

if [ -f $private_bridge-sahara-tests.log ]; then
    rm $private_bridge-sahara-tests.log; touch $private_bridge-sahara-tests.log
    check_return_code_after_command_execution $? "Fail while delete and create log file for tests"
fi

if [ ! -d sahara ]; then
    additional_parameters=''
    if [ ! -z $sahara_branch ]; then additional_parameters="-b $sahara_branch"; fi
    git clone https://github.com/openstack/sahara.git $additional_parameters >>/dev/null
    check_return_code_after_command_execution $? "Fail while clone savanna repository"
    if [ ! -z $sahara_commit_id ]; then
        cd sahara && git checkout $sahara_commit_id && cd $OLDPWD;
        check_return_code_after_command_execution $? "Fail while checkout savanna repository";
    fi
fi

prepare_config_and_start_tests
