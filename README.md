# CRS

Container Reverse Search

Get the shell!

```bash
curl -SsL https://git.io/fN403 > /usr/local/bin/crs
chmod +x /usr/local/bin/crs
crs -h
```

Get the binary! (TODO)

## Use cases

```bash
~$ crs -h
/usr/local/bin/crs [-option] [target]
  -i IP
  -m MAC
  -b Binds
  -v ID   # Get the veth of that container
  -V Veth # Get the container ID of that veth
  -p PID
  -P Port # alias of lsof
```

### Search IP 172.17.0.2

```bash
~$ crs -i 172.17.0.2
ContainerID  ContainerIP
62c69d9d216d 172.17.0.2
```

### Search Binds

```bash
~/components/consul/consul.d$ crs -b .
ContainerID  Binds
7f1750fde21f /root/components/consul/scripts:/scripts:rw/root/components/consul/consul.d:/etc/consul.d:rw
```

### Get container's veth

```bash
~$ crs -v 57025b6cd4e4
vethe9241df@if41
```

### Search veth's peer container

```bash
~$ crs -V vethe9241df
Veth         ContainerID
vethe9241df 57025b6cd4e4
```

### Search Process

```bash
~$ crs -p 56245
ERROR: Process not found
~$ crs -p 5082
ERROR: Process not inside a container
~$ crs -p 29675
Container: 73ce42d0b4ad
~$
```

### Search Ports (host mode)

```bash
~$ crs -P 8080
ERROR: Process not found
~$ crs -P 5082
ERROR: Process not inside a container
~$ crs -P 45678
Got PID 26215
Container: 3426225dca3f
```

In bridge mode, you can just use `docker ps | grep <port number>` to
find out whitch container use that port.