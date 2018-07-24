#!/bin/bash
# container reverse search
# works under Linux

# list all containers
IDS=$(docker ps -qa)

# formats
DI="docker inspect --format"
IP='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
MAC='{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}'
BINDS='{{range .HostConfig.Binds}}{{.}}{{end}}'


function inspect() {
  local format=$1
  local ID=$2
  local target=$3
  local found=$($DI "$format" $ID | grep "$target")
  [[ "$found" != "" ]] && echo $ID $found
}

function grepIP() {
  echo "ContainerID  ContainerIP"
  for id in `echo "$IDS"`;do
    inspect "$IP" "$id" ${1:-127.0.0.1}
  done
}

function grepBinds() {
  echo "ContainerID  Binds"
  for id in `echo "$IDS"`;do
    inspect "$BINDS" "$id" ${1:-"/etc/passwd"}
  done
}

function grepMAC() {
  echo "ContainerID  MAC"
  for id in `echo "$IDS"`;do
    inspect "$MAC" "$id" ${1:-":"}
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

# thanks to https://stackoverflow.com/a/28613516/4399982
function veth_interface_of_container() {
  local containerID="$1"
  local veth="$2"
  local vethIndex=$(ip link show | grep $veth | cut -d: -f2 | cut -d@ -f2 | cut -df -f2)
  # Get the process ID for the container named ${containerID}:
  local pid=$(docker inspect -f '{{.State.Pid}}' "${containerID}")

  # Make the container's network namespace available to the ip-netns command:
  mkdir -p /var/run/netns
  ln -sf /proc/$pid/ns/net "/var/run/netns/${containerID}"

  # Get the interface index of the container's eth0:
  local index=$(ip netns exec "${containerID}" ip link show eth0 | head -n1 | sed s/:.*//)
  
  [[ "$index" == "$vethIndex" ]] && FOUND_CONTAINERID=${containerID}

  # Clean up the netns symlink, since we don't need it anymore
  rm -f "/var/run/netns/${containerID}"
}

function grepVeth() {
  FOUND_CONTAINERID=""
  echo "Veth         ContainerID"
  local veth="$1"
  for id in `echo "$IDS"`;do
    veth_interface_of_container $id $veth
    [[ "$FOUND_CONTAINERID" != "" ]] && \
      echo "$veth" "$FOUND_CONTAINERID" && \
      exit 0
  done
}

function print_usage() {
  echo "$0 [-option] [target]
  -i IP
  -m MAC
  -b Binds
  -v ID   # Get the veth of that container
  -V Veth # Get the container ID of that veth
  -p PID
  -P Port
"
}

[[ "$1" == "" ]] && print_usage

while getopts 'i:m:b:v:V:p:P:h' flag; do
  case "${flag}" in
    i)  shift
      grepIP "$1"
      ;;
    m)  shift
      grepMAC "$1"
      ;;
    b)  shift
      grepBinds "$1"
      ;;
    v)  shift
      veth_interface_for_container "$1"
      ;;
    V)  shift
      grepVeth "$1"
      ;;
    p) echo "process" ;;
    P) echo "port" ;;
    h) print_usage ;;
    *) print_usage
  esac
done
