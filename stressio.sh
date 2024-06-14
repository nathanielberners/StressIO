#!/bin/bash
#
#   StressIO - stress test a mechanical hard drive by vomiting random data files, copying that vomit and
#   comparing the results. This will test a drive's I/O stability, even if S.M.A.R.T does not report a
#   fault. Using this, I have found bad drives that have passed all previous health checks.
#
#   Written by Nathaniel Berners.
#
#   WARNING - Using this script is destructive; make sure your data is backed up as it will be
#   irrecoverable afterwards! As such, this script comes with absolutely ZERO warranty:
#   DATA LOSS IS GUARANTEED!
#
#   To run StressIO, do as root:
#        stressio.sh /dev/<device>
#   where <device> is the drive identifier (such as sda, not an individual partion, such as sda1)
#

programName="StressIO";

### INIT ####################################################################################################

# Clear terminal function
function clearTerm {
    clear;
    printf "${programName} - Determine I/O issues with storage drives\n\n";
}
clearTerm;

# Test for root
if [[ `whoami` != "root" ]]; then
    printf "\tMust be root to run ${programName}. Aborting.\n\n";
    exit 1;
fi;

# Consent
printf "WARNING! All data on $1 WILL be destroyed. Continue? [N/y]: ";
read consent;
if [[ ${consent} != [yY] ]]; then
    printf "Cancelled.\n\n";
    exit 1;
fi;
clearTerm;
consent="";

# Last chance
printf "LAST CHANCE! Operation is about to begin on $1. Is this the correct drive? [N/y]: ";
read consent;
if [[ ${consent} != [yY] ]]; then
    printf "Cancelled\n\n";
    exit 1;
fi;
clearTerm;

# Check dependencies
dependencies=( "lsblk" "sed" "grep" "head" "tr" "awk" "cut" "dd" "parted" "mkfs.ext4" "sha1sum");
for i in "${dependencies[@]}"; do
    if [[ ! -f `which $i` ]]; then
        printf "\n\tMissing dependency: $i. Aborting.\n\n";
        exit 1;
    fi;
done;

# Device variables
devicePath="$1";
mountPath="/mnt/${programName}";
deviceName=`echo "$1" | sed -e 's/\/dev\///g'`;
deviceInfo=`lsblk -o NAME,SIZE,PHY-SeC,MODEL ${devicePath} | grep ${deviceName} | head -1 | tr -s [:space:]`;
driveSize=`echo ${deviceInfo} | awk '{print $2}' | awk -F '.' '{print $1}'`;
sectorSize=`echo ${deviceInfo} | awk '{print $3}'`;
logFile="${mountPath}/${programName}.log";
percentFill="45";

### RUN PROGRAM #############################################################################################

# Destroy partition table
printf "Destroying partition table... ";
umount ${devicePath}* &> /dev/null;
dd if=/dev/urandom of=${devicePath} bs=${sectorSize} count=3k &> /dev/null;
partprobe ${devicePath};
sleep 1s;
printf "Done\n";

# Create new GPT partition table
printf "Creating new partition layout... ";
parted -s ${devicePath} mklabel gpt;
parted -s ${devicePath} mkpart primary ext4 0% 100%;
partprobe ${devicePath}
sleep 1s;
printf "Done.\n";

# Create ext4 filesystem
printf "Creating ext4 filesystem... ";
mkfs.ext4 -F -L ${programName} ${devicePath}1 &> /dev/null;
printf "Done.\n";

# Create mountpoint and mount
printf "Mounting ${devicePath}1 to ${mountPath}... ";
if [ ! -d ${mountPath} ]; then
    mkdir ${mountPath};
fi;
mount ${devicePath}1 /mnt/${programName};
printf "Done.\n";
clearTerm;

# Begin writing data to partition
counter=0;
printf "Writing randomised data (time for coffee, date-night or maybe a holiday)... ";
while true; do
    ddcount=$((RANDOM % 512));
    ddmulti=$((RANDOM % 2));
    case ${ddmulti} in
        0)
            ddsuffix="";
            ;;
        1)
            ddsuffix="k";
            ;;
    esac;
    dd if=/dev/urandom of=${mountPath}/${counter}-1.dd bs=${sectorSize} count=${ddcount}${ddsuffix} status='none'; &> /dev/null
    testSpace=`df ${mountPath} | grep ${mountPath} | head -1 | awk '{print $5}' | sed -e 's/%//'`;
    if [[ ${testSpace} -ge ${percentFill} ]]; then
        break;
    fi;
    counter=$(( ${counter}+1 ));
done;
printf "Done.\n";
printf "Reverse copying randomised data (time for another date-night ;) )... ";
while true; do
    cp ${mountPath}/${counter}-1.dd ${mountPath}/${counter}-2.dd;
    if [ ${counter} == 0 ]; then
        break;
    fi;
    counter=$(( ${counter}-1 ));
done;
printf "Done.\n";

# Compare data fingerprints
counter=0;
numErrors=0;
printf "Checking data integrity, reporting in ${logFile} ... ";
while true; do
    if [[ ! -f "${mountPath}/${counter}-1.dd" ]]; then
        break;
    fi;
    printf "${counter}-1.dd vs. ${counter}-2.dd... " >> ${logFile};
    SUM1=`sha1sum ${mountPath}/${counter}-1.dd | awk '{print $1}'`;
    SUM2=`sha1sum ${mountPath}/${counter}-2.dd | awk '{print $1}'`;
    if [[ ${SUM1} != ${SUM2} ]]; then
        printf "FAILED.\n" >> ${logFile};
        printf "${SUM1}\n${SUM2}\n\n" >> ${logFile};
        numErrors=$(( ${numErrors}+1 ));
    else
        printf "OK.\n" >> ${logFile};
    fi;
    counter=$(( ${counter}+1 ));
done;

numData=`du -c ${mountPath}/*.dd | grep total`;
printf "Data created = ${numData} bytes.\n" >> ${logFile};
printf "${numErrors} test failures. " >> ${logFile};
if [ ${numErrors} -ge 1 ]; then
    printf "Possible issues with drive I/O integrity." >> ${logFile};
else
    printf "Drive is likely OK." >> ${logFile};
fi;
printf "Done.\n\n";

### END PROGRAM #############################################################################################
printf "=== RESULTS ========================================\n";
cat ${logFile};
printf "\n====================================================\n\n";

printf "Tidying up; could take a while for slow devices, please be patient... ";
umount ${mountPath};
rm -rf ${mountPath};
printf "Done.\n\n";

printf "${programName} Finished.\n\n";
exit 0;
