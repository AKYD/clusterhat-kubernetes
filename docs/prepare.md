## Prepare stuff for Pi :

Add repo for docker :

`echo 'deb [arch=armhf] https://download.docker.com/linux/raspbian stretch edge' > /etc/apt/sources.list.d/docker.list`

`apt-get update && apt-get install docker-ce=18.06.3~ce~3-0~raspbian`

Also on pi zero the default *pause* container will crash so we'll build our own image (and specify the custom pause image in the kubelet startup settings)
You can load the build image from [here](../files/workers-pi-zero/pause_container)

`docker load < pause_container.tar`

or build your own (I used [this one](https://github.com/Project31/kubernetes-installer-rpi.git) )

### Enable cgroups

On each Pi (controller + 4 zeros) add the following to **/boot/cmdline.txt**

`cgroup_enable=cpuset cgroup_enable=memory cgroup_enable=pids cgroup_memory=1`

### Enable the systemd-resolved.service 

`systemctl enable systemd-resolved.service && systemctl start systemd-resolved.service`

### CNI

`wget https://github.com/containernetworking/plugins/releases/download/v0.7.4/cni-plugins-arm-v0.7.4.tgz`

### Kernel for Pi zero
#### Compile our own

I've tested all the kernel versions from **4.14.x** up to **4.19.x** from the *raspberrypi* repo and couldn't get any to work

I've had success with the **4.9.y** branch

( Additional packages mught be needed for compiling stuff)

On a linux machine run:

`git clone --single-branch --branch rpi-4.9.y-stable  https://github.com/raspberrypi/linux`

`cd linux`

`make config`

*make sure that cgroup and cpuset stuff is enabled*

```
CONFIG_CGROUPS=y
CONFIG_BLK_CGROUP=y
CONFIG_DEBUG_BLK_CGROUP=y
CONFIG_CGROUP_WRITEBACK=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_PERF=y
CONFIG_CGROUP_DEBUG=y
# CONFIG_NETFILTER_XT_MATCH_CGROUP is not set
CONFIG_NET_CLS_CGROUP=m
CONFIG_SOCK_CGROUP_DATA=y
CONFIG_CGROUP_NET_PRIO=y
CONFIG_CGROUP_NET_CLASSID=y
CONFIG_CPUSETS=y
CONFIG_PROC_PID_CPUSET=y
```

*maybe comment the lines about oldconfig in scripts/kconfig/Makefile*

`make KCONFIG_CONFIG=.config ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage  modules -j 8`

`mkdir modz`

`make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=modz modules_install`

*copy the kernel and modules to pi zero*

`scp arch/arm/boot/zImage clusterhat:/var/lib/clusterhat/nfs/p1/boot/kernel-4.9.80+.img`

`tar cvf modz.tar modz/*`

`scp modz.tar clusterhat:/var/lib/clusterhat/nfs/p1/lib/modules/`

#### Set up the new kernel on pi zero 

*unarchive the modz.tar*

`cd /lib/modules/ && tar xvf modz.tar && rm -f modz.tar`

`mkinitramfs -o /boot/initramfs-4.9.80+.img 4.9.80+`

*edit **/boot/config.txt** and add the line*

`kernel = kernel-4.9.80+.img`

*at the end of the file change the initramfs option for pi0*

```
[pi0]
# initramfs initramfs.img
initramfs initramfs-4.9.80+.img
```

`reboot`

#### Or install from the repo (it will take *ages*)

`apt-get install linux-image-4.9.0-6-rpi:armhf`

and edit **/boot/config.txt**

`kernel=vmlinuz-4.9.0-6-rpi`

`initramfs initrd.img-4.9.0-6-rpi`

and

`reboot`

### Compiling the Kubernetes components

You can skip these steps and use the compiled binaries from the [**files**](files) directory

On a linux machine :

`git clone https://github.com/kubernetes/kubernetes && cd kubernetes && git checkout v.1.13.3`

(Again, additional packages might be needed for compiling stuff)

`apt-get install gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi`

*create the **zero** and **controller** dirs on the controller so we know where files belong*

#### Compiling the controller files (Rpi 3)

##### etcd

`git clone https://github.com/etcd-io/etcd`

`cd etcd`

`GOARCH=arm GOARM=5 go build`

`scp etcd controller:controller`

Also compile etcdctl

`cd etcdctl && GOARCH=arm GOARM=5 go build`

`scp etcdctl controller:controller`

You can probably install etcd on the controller using *apt*

##### kubernetes components

```
for item in kube-apiserver kube-scheduler kube-controller-manager kubectl kubelet kube-proxy; do
	make all WHAT=cmd/${item} KUBE_VERBOSE=5 KUBE_BUILD_PLATFORMS=linux/arm
done
```

`scp _output/local/bin/linux/arm/* clusterhat:controller`

`rm -f _output/local/bin/linux/arm`

#### Compiling the worker files (Rpi zero)

You need to modify the **hack/lib/golang.sh** file like so :

add `export GOARM=6` at line 311
change `export CC=arm-arm-linux-gnueabi-gcc` at line 321

This is how the area of the file looks like after editing :

```
   309   export GOOS=${platform%/*}
   310   export GOARCH=${platform##*/}
   311   export GOARM=6
   312 
   313   # Do not set CC when building natively on a platform, only if cross-compiling from linux/amd64
   314   if [[ $(kube::golang::host_platform) == "linux/amd64" ]]; then
   315     # Dynamic CGO linking for other server architectures than linux/amd64 goes here
   316     # If you want to include support for more server platforms than these, add arch-specific gcc names here
   317     case "${platform}" in
   318       "linux/arm")
   319         export CGO_ENABLED=1
   320         #export CC=arm-linux-gnueabihf-gcc
   321         export CC=arm-linux-gnueabi-gcc
   322         ;;
```

```
for item in kubelet kube-proxy; do
	make all WHAT=cmd/${item} KUBE_VERBOSE=5 KUBE_BUILD_PLATFORMS=linux/arm
done
```

`scp _output/local/bin/linux/arm/* clusterhat:zero`