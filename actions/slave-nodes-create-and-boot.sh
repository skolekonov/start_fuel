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

echo -n "Install worker nodes... "
sudo screen -dmS $name-1 virt-install --connect qemu:///system --virt-type kvm -n $name-1 -r $vm_slave_memory_mb --vcpus $vm_slave_cpu_cores -f "/tmp/${name}-1" -s $vm_slave_disk_gb --pxe -w bridge:$private_bridge -w bridge:$public_bridge --vnc
await_vm_status name-1 "работает"
if $HA_mode; then
    sudo screen -dmS $name-2 virt-install --connect qemu:///system --virt-type kvm -n $name-2 -r $vm_slave_memory_mb --vcpus $vm_slave_cpu_cores -f "/tmp/${name}-2" -s $vm_slave_disk_gb --pxe -w bridge:$private_bridge -w bridge:$public_bridge --vnc
    await_vm_status name-2 "работает"
    sudo screen -dmS $name-3 virt-install --connect qemu:///system --virt-type kvm -n $name-3 -r $vm_slave_memory_mb --vcpus $vm_slave_cpu_cores -f "/tmp/${name}-3" -s $vm_slave_disk_gb --pxe -w bridge:$private_bridge -w bridge:$public_bridge --vnc
    await_vm_status name-3 "работает"
fi
echo "OK"

for counter in $(eval echo {1..$mashines_count}); do
    type="mashine_$counter"
    eval host=\$${type}_host
    eval user=\$${type}_user
    eval role=\$${type}_role
    eval pass=\$${type}_password
    echo "Reboot hardware machine $host using IPMI... "
    sudo ipmitool -I lanplus -H $host -U $user -L $role -P $pass chassis power reset 1>/dev/null
    check_return_code_after_command_execution $? "An error occurred while reboot hardware machine"
    echo "OK"
done
