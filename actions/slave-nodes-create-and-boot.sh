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
source functions/vm.sh

name="${vm_name_prefix}worker-$private_bridge"

# Start KVM nodes

for counter in $(eval echo {1..$kvm_nodes_count}); do
    if ! [ -z "`sudo virsh vol-list --pool default | grep $name-$counter`" ]; then sudo virsh vol-delete --pool default $name-$counter.qcow2; fi
    sudo virsh vol-create-as --name $name-$counter.qcow2 --capacity ${vm_slave_disk_gb}G --format qcow2 --allocation ${vm_slave_disk_gb}G --pool default

    sudo screen -dmS $name-$counter virt-install --connect qemu:///system --virt-type kvm -n $name-$counter -r $vm_slave_memory_mb --vcpus $vm_slave_cpu_cores --disk path=/var/lib/libvirt/images/$name-$counter.qcow2,cache=writeback,bus=virtio --pxe -w bridge=$private_bridge,model=virtio -w bridge=$public_bridge,model=virtio --vnc
    await_vm_status $name-$counter "работает"
    echo -n "Install worker node $name-$counter"
    echo_ok
done

# Reboot IPMI nodes

for counter in $(eval echo {1..$mashines_count}); do
    type="mashine_$counter"
    eval host=\$${type}_host
    eval user=\$${type}_user
    eval role=\$${type}_role
    eval pass=\$${type}_password
    echo -n "Reboot hardware machine $host using IPMI... "
    sudo ipmitool -I lanplus -H $host -U $user -L $role -P $pass chassis power reset 1>/dev/null
    check_return_code_after_command_execution $? "An error occurred while reboot hardware machine"
    echo_ok
done
