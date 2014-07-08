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

# This file contains the functions for connecting to Fuel VM, checking if the installation process completed
# and Fuel became operational, and also enabling outbound network/internet access for this VM through the
# host system

source  functions/vm.sh
source  functions/resources.sh

is_product_vm_operational() {
    name=$1

    # Log in into the VM, see if Puppet has completed its run
    # Looks a bit ugly, but 'end of expect' has to be in the very beginning of the line

    is_directory=$(sudo virt-ls $name /var/log/ 2>/dev/null | grep puppet | wc -l)
    if [ $is_directory != "0" ]; then is_file=$(sudo virt-ls $name /var/log/puppet/ 2>/dev/null | grep bootstrap_admin_node.log | wc -l); else is_file="0"; fi
    if [ $is_file != "0" ]; then result=$(sudo virt-cat $name /var/log/puppet/bootstrap_admin_node.log 2>/dev/null); else result=""; fi

    # When you are launching command in a sub-shell, there are issues with IFS (internal field separator)
    # and parsing output as a set of strings. So, we are saving original IFS, replacing it, iterating over lines,
    # and changing it back to normal
    #
    # http://blog.edwards-research.com/2010/01/quick-bash-trick-looping-through-output-lines/

    OIFS="${IFS}"
    NIFS=$'\n'
    IFS="${NIFS}"

    for line in $result; do
        IFS="${OIFS}"
        if [[ $line == *otice:\ Finished\ catalog\ run\ in* ]]; then
            IFS="${NIFS}"
            echo -n "Waiting for Fuel Master install..."
            return 0;
        fi
        IFS="${NIFS}"
    done

    return 1
}

wait_for_product_vm_to_install() {
    name=$1
    source $2
    echo "Waiting for product VM to install. Please do NOT abort the script... "
    await_vm_status $name "работает"
    counter=0

    # Loop until master node gets successfully installed

    while ! is_product_vm_operational $name; do
        let counter=counter+1
        state=`virsh domstate $name`
        check_return_code_after_command_execution $? "virtual machine $1 not found"
        if [ "$state" == "выключен" -o  "$state" == "shut off" ]
        then
            edit_file_on_vm $name /etc/sysconfig/network-scripts/ifcfg-eth0 "s/^IPADDR.*/IPADDR=$vm_master_ip/"
            edit_file_on_vm $name /etc/sysconfig/network-scripts/ifcfg-eth0 "s/^NETMASK.*/NETMASK=$vm_master_netmask/"
            edit_file_on_vm $name /etc/sysconfig/network "s/^GATEWAY.*/GATEWAY=$vm_master_gateway/"
            edit_file_on_vm $name /etc/hosts "s/10.20.0.2/$vm_master_ip/"
            edit_file_on_vm $name /etc/dnsmasq.upstream "s/10.20.0.1/$vm_master_gateway/"
            edit_file_on_vm $name /etc/puppet/modules/puppet/manifests/pull.pp "s/10.20.0.2/$vm_master_ip/"
            sudo guestfish -i --rw -d $name rm /etc/naily.facts
            sudo guestfish -i --rw -d $name write /etc/naily.facts "$naily"
            virsh start $name &>/dev/null
            await_vm_status $name "работает"
        fi;
        if [ $counter -eq $[$fuel_master_install_timeout*2] ]
        then
            echo "Fuel Master does not start for $fuel_master_install_timeout minutes"
            exit 1
        fi
        sleep 30
        if [ $((counter % 2)) = 0 ]; then echo "Waiting start Fuel Master $[$counter/2] minutes"; fi
    done
}

check_network_params() {
    echo "Check Fuel Master network settings. Please do NOT abort the script"
    await_open_port $vm_master_ip "8000"
}
