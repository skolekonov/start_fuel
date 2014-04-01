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

source functions/resources.sh

if [ ! -d savanna-tests-scripts ]; then
    git clone https://github.com/vrovachev/savanna-tests-scripts.git >>/dev/null
    check_return_code_after_command_execution $? "Fail while clone savanna_prepare repository"
fi
rm savanna-tests-scripts/settings.py 1>>/dev/null &&
cp iso_settings.py savanna-tests-scripts/settings.py 1>>/dev/null &&
python savanna-tests-scripts/prepare_for_tests.py $1 >>/dev/null
check_return_code_after_command_execution $? "Fail while clone savanna_prepare repository"


