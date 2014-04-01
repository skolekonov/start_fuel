#!/bin/sh

SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

check_return_code_after_command_execution() {
    if [ "$1" -ne 0 ]
        then
        if [ ! -z "$2" ]
            then
            $SETCOLOR_FAILURE
            echo "$(tput hpa $(tput cols))$(tput cub 6)[fail]"
            echo "$2"
            $SETCOLOR_NORMAL
        fi
        exit 1
    fi
}

echo_ok() {
    $SETCOLOR_SUCCESS
    echo "$(tput hpa $(tput cols))$(tput cub 6)[OK]"
    $SETCOLOR_NORMAL
}

await_open_port() {
    counter=0
    echo -n "Waiting port $2 availability at virtual machine $1... "
    while ! echo q | telnet -e q $1 $2 2>/dev/null | grep -oq Connected &> /dev/null; do
        let counter=counter+1
        if [ $counter -eq 24 ]
        then
            echo "Expected port $2 at virtual machine $1 is not obtained in 2 minutes"
            exit 1
        fi
        sleep 5
    done
    echo "OK"
}
