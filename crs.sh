#!/bin/bash
# container reverse search
# works under Linux
# use sed, ip, lsof, grep, and also, docker

# list all containers
IDS=$(docker ps -q)

# formats
DI="docker inspect --format"
IP='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
MAC='{{range .NetworkSettings.Networks}}{{.MacAddress}}{{end}}'
BINDS='{{range .HostConfig.Binds}}{{.}}{{end}}'
SANDBOX='{{.NetworkSettings.SandboxID}}'
PORTS='{{range .NetworkSettings.Ports}}{{range .}}{{ printf "%s " .HostPort}}{{end}}{{end}}'
HOST_NETWORK='{{range $cid, $conf := .Containers}}{{printf "%s %s\n" $cid $conf.EndpointID}}{{end}}'

function inspect() {
  local format=$1
  local ID=$2
  local target=$3
  local found=$($DI "$format" $ID | grep "$target")
  [[ "$found" != "" ]] && echo "$ID $found"
}

function searchIP() {
  [[ "$1" == "" ]] && EXIT "IP is empty"
  echo "ContainerID  ContainerIP"
  for id in `echo "$IDS"`;do
    inspect "$IP" "$id" $1
  done
}

function searchBinds() {
  bind_file=$1
  [[ "$1" == "" ]] && EXIT "Binds is empty"
  [[ "$1" == "." ]] && bind_file=`pwd`
  echo "ContainerID  Binds"
  for id in `echo "$IDS"`;do
    inspect "$BINDS" "$id" "$bind_file"
  done
}

function searchMAC() {
  [[ "$1" == "" ]] && EXIT "MAC is empty"
  echo "ContainerID  MAC"
  for id in `echo "$IDS"`;do
    inspect "$MAC" "$id" ${1:-":"}
  done
}

# thanks to https://stackoverflow.com/a/28613516/4399982
function veth_interface_for_container() {
  # Get the process ID for the container named ${1}:
  local pid=$(docker inspect -f '{{.State.Pid}}' "${1}")
  [[ "$pid" -eq 0 ]] && return 0
  
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

  # if pid == 0, means the container is not running
  [[ "$pid" -eq 0 ]] && return 0

  # Make the container's network namespace available to the ip-netns command:
  mkdir -p /var/run/netns
  ln -sf /proc/$pid/ns/net "/var/run/netns/${containerID}"

  # Get the interface index of the container's eth0:
  local index=$(ip netns exec "${containerID}" ip link show eth0 | head -n1 | sed s/:.*//)
  
  [[ "$index" == "$vethIndex" ]] && export FOUND_CONTAINERID=${containerID}

  # Clean up the netns symlink, since we don't need it anymore
  rm -f "/var/run/netns/${containerID}"
}

function searchVeth() {
  FOUND_CONTAINERID=""
  local veth="$1"
  [[ "$veth" == "" ]] && EXIT "Veth is empty"
  echo "Veth        ContainerID"
  for id in `echo "$IDS"`;do
    veth_interface_of_container $id $veth
    if [[ "$FOUND_CONTAINERID" != "" ]];then
      echo "$veth $FOUND_CONTAINERID"
      exit 0
    fi
  done
}

function searchSandbox() {
  local key="$1"
  [[ "$key" == "" ]] && EXIT "sanbox key not found"
  for ID in `echo "$IDS"`;do
    found=$($DI "$SANDBOX" $ID | grep "$key")
    [[ "$found" != "" ]] && echo "Container: $ID" && return 0
  done
}

function searchHost() {
  for ID in `echo "$IDS"`;do
    pids=$(docker top $ID -exo pid | sed 1d)
    found=$(echo $pids | grep $1)
    [[ "$found" != "" ]] && echo "Container: $ID" && return 0
  done
  return 1
}

function searchProcess() {
  local pid=$1
  [[ "$pid" == "" ]] && EXIT "PID not found"
  local ns=$(readlink /proc/${pid}/ns/net | sed "s/.*\[\(.*\)\]/\1/g")
  [[ "${ns}" == "" ]] && EXIT "Process not found"
  local sandBox=$(ls -li /run/docker/netns | grep ${ns} | sed "s/.*\ \(.*\)/\1/")
  if [[ "$sandBox" == "default" ]];then
    searchHost "$pid" || EXIT "Process not inside a container"
  else
    searchSandbox $sandBox
  fi
}

function searchPorts() {
  [[ "$1" -lt 0 ]] && EXIT "Invalid Port"
  local PID=$(lsof -i :"$1" -T -P | grep TCP | head -1 | tr -s " " | cut -d" " -f2)
  printf "Got PID %s\n" $PID
  searchProcess $PID
}

function EXIT() {
  echo "ERROR: $1"
  exit 1
}

function print_usage() {
  echo "$0 [-option] [target]
  -i IP
  -m MAC
  -b Binds
  -v ID   # Get the veth of that container
  -V Veth # Get the container ID of that veth
  -p PID
  -P Port # alias of lsof
"
}

[[ "$1" == "" ]] && print_usage

while getopts 'i:m:b:v:V:p:P:h' flag; do
  case "${flag}" in
    i) shift
      searchIP "$1"
      ;;
    m) shift
      searchMAC "$1"
      ;;
    b) shift
      searchBinds "$1"
      ;;
    v) shift
      veth_interface_for_container "$1"
      ;;
    V) shift
      searchVeth "$1"
      ;;
    p) shift
      searchProcess "$1"
      ;;
    P) shift
      searchPorts "$1"
      ;;
    h) print_usage ;;
    *) print_usage
  esac
done
