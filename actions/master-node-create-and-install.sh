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

# Include the handy functions to operate VMs and track ISO installation progress
source $1
source functions/product.sh
source functions/resources.sh

name="${vm_name_prefix}master-$private_bridge"

if [ ! -d ~/dir_for_images/ ]; then
    echo -n "Create directory for kvm images... "
    mkdir ~/dir_for_images/
    echo_ok
fi

screen -dmS $name sudo virt-install --connect qemu:///system --virt-type kvm -n $name -r $vm_master_memory_mb --vcpus $vm_master_cpu_cores -f "`echo ~`/dir_for_images/${name}" -s $vm_master_disk_gb -c $iso_path -b $private_bridge --vnc --noreboot

wait_for_product_vm_to_install $name $1

check_network_params $name $1

echo_ok
