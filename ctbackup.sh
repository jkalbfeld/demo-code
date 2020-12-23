#!/bin/bash
# 
# Jonathan Kalbfeld
#
# Use this script for backing up proxmox containers by 
# mirroring ZFS storage to the remote destination host
#
#

snap="$(date +%s)-snap"
dir="$(mktemp -d)"

usage() { echo "Usage: $0 -s <container home> -n <container num> -d <destination>" 1>&2; exit 1; }

while getopts ":s:n:d:" o; do
    case "${o}" in
        s)
            source=${OPTARG}
	    mp=$(mount | grep $source | awk '{print $3}')
            ;;
        n)
            ctnum=${OPTARG}
            ;;
	d)
	    dest=${OPTARG}
	    ;;
        *)
            usage
            ;;
    esac
done

if [ -z "${source}" ] || [ -z "${ctnum}" ] || [ -z "${dest}" ]; then
    usage
fi
destserver=$(echo $dest | cut -f1 -d:)
ctstatus=$(ssh $destserver "pct status $ctnum" | awk '{print $2}')

if [ x"$status" != x" running" ];
then
 echo "********* Taking a snapshot of $source@$snap *********"
 zfs snapshot $source@$snap 2>&1
 echo "******** Copying the snapshot to temp storage ********"
 rsync --progress -aH --inplace $mp/images/$ctnum $dir/ 2>&1
 echo "************** Destroying the snapshot ***************"
 zfs destroy $source@$snap 2>&1
 echo "******* Copying the snapshot to remote storage *******"
 rsync --progress -aH -e 'ssh -C' --inplace $dir/ $dest 2>&1
 echo "******************** Cleaning up *********************"
 rm -rf $dir
else 
 echo "Container $ctnum is running on ${destserver}. Exiting."
fi
