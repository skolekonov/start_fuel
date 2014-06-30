#!/bin/bash 

#    Copyright 2013 Mirantis, Inc.
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
private_bridge=br1086

#
public_bridge=br19

#
fuel_master_install_timeout=60

# Get the first available ISO from the directory 'iso'
iso_path=`ls -1t iso/*.iso 2>/dev/null | head -1`

# Every Mirantis OpenStack machine name will start from this prefix
vm_name_prefix=fuel-

#
kvm_nodes_count=3

# Master node settings
vm_master_cpu_cores=1
vm_master_memory_mb=1024
vm_master_disk_gb=30

# These settings will be used to check if master node has installed or not.
# If you modify networking params for master node during the boot time
#   (i.e. if you pressed Tab in a boot loader and modified params),
#   make sure that these values reflect that change.
vm_master_ip=10.20.0.2
vm_master_gateway=10.20.0.1
vm_master_netmask=255.255.255.0

# Slave node settings
vm_slave_cpu_cores=2
vm_slave_memory_mb=3072
vm_slave_disk_gb=50

# network settings for Fuel Master
naily="mnbs_internal_interface=eth0
mnbs_internal_ipaddress=10.20.0.2
mnbs_internal_netmask=255.255.255.0
mnbs_static_pool_start=10.20.0.130
mnbs_static_pool_end=10.20.0.250
mnbs_dhcp_pool_start=10.20.0.10
mnbs_dhcp_pool_end=10.20.0.120"

# Settings for ipmi mashines

mashines_count=1

mashine_1_host=srv23-srt-ipmi.srt.mirantis.net
mashine_1_user=engineer
mashine_1_role=Operator
mashine_1_password=iKiePh4e

environment_settings=env_config_1086_nova_network.cfg

savanna_test_settings=test_config_nova_network.conf

sahara_branch=master

sahara_commit_id=a170a05bc6dce1462a24622c55f74fb6e39db884
