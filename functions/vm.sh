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

# This file contains the functions to manage VMs in through virsh

source  functions/resources.sh

await_vm_status() {
    counter=0
    max_count=12
    sec_state=''
    if [ $2 == "работает" ]; then $sec_state='Running';
    elif [ $2 == "выключен" ]; then sec_state='Shutoff';
    elif [ $2 == "Приостановлена" ]; then sec_state='Paused';
    fi
    while [  $counter -lt $max_count ]; do
        sleep 5
        vm_state=$(virsh domstate $1 2>/dev/null; check_return_code_after_command_execution "$?" "vm $1 not fount")
        if [ ! -z $vm_state ] && [ $vm_state == $2 -o $vm_state == $sec_state ]; then break; fi
        if [ $counter == $max_count ]; then echo -e "\nvirtual machine $1 didn't pass into $2 status of 2 minutes"; exit 1; fi
        let counter=counter+1
    done
}

start_vm() {
    vm_state=$(virsh domstate $1)
    check_return_code_after_command_execution $? "virtual machine $1 not found"
    if [ $vm_state == "выключен" ]
    then
        virsh start $1
        await_vm_status "работает" $1
    else
        echo
        echo "virtual machine $1 already started"
    fi;
}

shutdown_vm() {
    vm_state=$(virsh domstate $1)
    check_return_code_after_command_execution $? "virtual machine $1 not found"
    if [ $vm_state == "работает" ]
    then
        virsh shutdown $1
        await_vm_status "выключен" $1
    else
        echo
        echo "virtual machine $1 already stoped"
    fi;
}

destroy_vm() {
    vm_state=$(virsh domstate $1)
    check_return_code_after_command_execution $? "virtual machine $1 not found"
    if [ $vm_state == "работает" ]
    then
        virsh destroy $1
        await_vm_status "выключен" $1
    else
        echo
        echo "virtual machine $1 already stoped"
    fi;
}

reboot_vm() {
    vm_state=$(virsh domstate $1)
    check_return_code_after_command_execution $? "virtual machine $1 not found"
    virsh reboot $1
    await_vm_status "работает" $1
}

edit_file_on_vm() {
# $1 - name of vm
# $2 - path to file
# $3 - regular expression to edit file
sudo virt-edit -d $1 $2 -e $3
}
