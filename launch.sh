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

if [ -z $1 ]; then
	echo -e "Config file not specified, attempt to find config file..."
	config=`ls -1t deploy_config* | head -1`
	if [ -z $config ]; then
		echo -e "Config file not specified and not found, please create config file. Aborting."; exit 1;
	else
		echo -e "Found file: $config"
	fi
else
    config=$1
fi

source $config
source functions/resources.sh

# Prepare the host system
./actions/prepare-environment.sh $config
check_return_code_after_command_execution $? "prepare environment is failed"

# Create and launch master node
sudo ./actions/master-node-create-and-install.sh $config
check_return_code_after_command_execution $? "Create or install master node is failed"

# Create and launch slave nodes
sudo ./actions/slave-nodes-create-and-boot.sh $config
check_return_code_after_command_execution $? "Create or boot worker nodes is failed"

# Create and deploy environment
python nailgun.py $environment_settings $vm_master_ip $kvm_nodes_count $mashines_count
check_return_code_after_command_execution $? "Create of deploy OpenStack environment is failed"

# Save environment ip
env_ip=$(python -c "import nailgun; nailgun.return_controller_ip(\"$environment_settings\", \"$vm_master_ip\")")
check_return_code_after_command_execution $? "IP of OpenStack environment not obtained"

# Add Savanna ISO for tests
./actions/add_savanna_iso.sh $env_ip || exit 1

# Run Savanna Tests
./actions/start_tests.sh $config $env_ip
