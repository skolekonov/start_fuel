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

if ! [ -z "`sudo virsh vol-list --pool default | grep $name`" ]; then sudo virsh vol-delete --pool default $name.qcow2; fi
sudo virsh vol-create-as --name $name.qcow2 --capacity ${vm_master_disk_gb}G --format qcow2 --allocation ${vm_master_disk_gb}G --pool default

screen -dmS $name sudo virt-install --connect qemu:///system --virt-type kvm -n $name -r $vm_master_memory_mb --vcpus $vm_master_cpu_cores -c $iso_path -w bridge=$private_bridge,model=virtio --disk path=/var/lib/libvirt/images/$name.qcow2,cache=writeback,bus=virtio --vnc --noreboot

wait_for_product_vm_to_install $name $1

check_network_params $name $1
