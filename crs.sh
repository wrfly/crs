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

# thanks to https://stackoverflow.com/a/28613516/4399982
function veth_interface_for_container() {
  # Get the process ID for the container named ${1}:
  local pid=$(docker inspect -f '{{.State.Pid}}' "${1}")

  # Make the container's network namespace available to the ip-netns command:
  mkdir -p /var/run/netns
  ln -sf /proc/$pid/ns/net "/var/run/netns/${1}"

  # Get the interface index of the container's eth0:
  local index=$(ip netns exec "${1}" ip link show eth0 | head -n1 | sed s/:.*//)
  # Increment the index to determine the veth index, which we assume is
  # always one greater than the container's index:
  let index=index+1

  # Write the name of the veth interface to stdout:
  ip link show | grep "^${index}:" | sed "s/${index}: \(.*\):.*/\1/"

  # Clean up the netns symlink, since we don't need it anymore
  rm -f "/var/run/netns/${1}"
}

function grepVeth() {
    veth_interface_for_container $1
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
        v)
            shift
            grepVeth $1
        ;;
        p) echo "process" ;;
        *) print_usage
    esac
done