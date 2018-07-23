#!/bin/bash
# container reverse search

# list all containers
IDS=$(docker ps -qa)

# formats
DI="docker inspect --format"
IP='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
MAC='{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}'
BINDS='{{range .HostConfig.Binds}}{{.}}{{end}}'

function inspectIP() {
    local ID=$1
    local targetIP=$2
    local foundIP=$($DI "$IP" $ID | grep "$targetIP")
    [[ "$foundIP" != "" ]] && echo $ID $foundIP
}


function grepIP() {
    for id in `echo "$IDS"`;do
        inspectIP $id ${1:-127.0.0.1}
    done
}

function print_usage() {
    echo "Usage: ..."
}

while getopts 'i:f:v:p:' flag; do
    case "${flag}" in
        i)
            shift
            grepIP $1 
        ;;
        f) echo "file" ;;
        v) echo "veth" ;;
        p) echo "process" ;;
        *) print_usage
    esac
done