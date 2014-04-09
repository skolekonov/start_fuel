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
# This script performs initial check and configuration of the host system. It:
#   - verifies that all available command-line tools are present on the host system
#   - check that there is no previous installation of Mirantis OpenStack (if there is one, the script deletes it)
#   - creates host-only network interfaces
#
# We are avoiding using 'which' because of http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script 
#

# Include the script with handy functions to operate VMs and VirtualBox networking
source $1
source functions/resources.sh

# Check for kvm
echo -n "Checking for 'kvm'... "
kvm --version >/dev/null 2>&1 || { sudo apt-get update >>install.log 2>&1 && sudo apt-get install kvm -y >>install.log 2>&1; } || { echo >&2 "'kvm' is not available in the path, but it's required. Please install 'kvm' package. Aborting."; exit 1; }
echo_ok

# Check for virt-manager
echo -n "Checking for 'virt-manager'... "
virt-manager --version >/dev/null 2>&1 || { sudo apt-get update >>install.log 2>&1 && sudo apt-get install virt-manager -y >>install.log 2>&1; } || { echo >&2 "'virt-manager' is not available in the path, but it's required. Likely, virt-manager is not installed. Aborting."; exit 1; }
echo_ok

# Check for virt-tools
echo -n "Checking for 'virt-tools'... "
virt-edit --version >/dev/null 2>&1 || { sudo apt-get update >>install.log 2>&1 && sudo apt-get install libvirt-dev -y >>install.log 2>&1 && sudo apt-get install libguestfs-tools -y | tee -a install.log; } || { echo >&2 "'virt-tools' is not available in the path, but it's required. Likely, virt-tools is not installed. Aborting."; exit 1; }
echo_ok

# Check for guestfish
echo -n "Checking for 'guestfish'... "
guestfish --version >/dev/null 2>&1 ||  { sudo apt-get update >>install.log 2>&1 && sudo apt-get install guestfish -y >>install.log 2>&1; } || { echo >&2 "'guestfish' is not available in the path, but it's required. Likely, guestfish is not installed. Aborting."; exit 1; }
echo_ok

# Check for virsh
echo -n "Checking for 'virsh'... "
virsh -v >/dev/null 2>&1 || { sudo apt-get update >>install.log 2>&1 && sudo apt-get install libvirt-bin -y >>install.log 2>&1; } || { echo >&2 "'guestfish' is not available in the path, but it's required. Likely, guestfish is not installed. Aborting."; exit 1; }
echo_ok

# Check for ipmitool
echo -n "Checking for ipmitool... "
ipmitool -V >/dev/null 2>&1 || { sudo apt-get update >>install.log 2>&1 && sudo apt-get install ipmitool -y >>install.log 2>&1; } || { echo >&2 "'ipmitool' is not available in the path, but it's required. Likely, ipmitool is not installed. Aborting."; exit 1; }
echo_ok

# Check for master Fuel ISO image to be available
echo -n "Checking for Mirantis OpenStack ISO image... "
if [ -z $iso_path ]; then
    echo "Mirantis OpenStack image is not found. Please download it and put under 'iso' directory."
    exit 1
fi
echo_ok

# Check for environment settings to be available
echo -n "Checking for environment settings... "
if [ ! -f $environment_settings ]; then
    echo "Environment settings is not found. Please download it and put under 'iso' directory."
    exit 1
fi
echo_ok

# Check for savanna ISO settings to be available
echo -n "Checking for ISO settings... "
if [ ! -f iso_settings.py ]; then
    echo "ISO settings is not found. Please download it and put under 'iso' directory."
    exit 1
fi
echo_ok

# Check for savanna tests settings to be available
echo -n "Checking for savanna tests settings... "
if [ ! -f $savanna_test_settings ]; then
    echo "Savanna tests settings is not found. Please download it and put under 'iso' directory."
    exit 1
fi
echo_ok

#Check for network
echo -n "Checking for network settings... "
ifconfig $private_bridge 1>/dev/null
check_return_code_after_command_execution $? "info for bridge:$private_bridge not found, please change network settings or parameters in config file"
ifconfig $public_bridge 1>/dev/null
check_return_code_after_command_execution $? "info for bridge:$public_bridge not found, please change network settings or parameters in config file"
echo_ok

# Report success
echo "Setup is done."


