#!/bin/bash
#################################################################################################################
#
#           This script will help is automating the Perf Stats collection process. 
# -------------------------------------------------------------------------------------------------------------
#
#          FILE:  collectorPerf.sh
#         USAGE:  ./collectPerf.sh
#        AUTHOR:  STALIN STEPIN.
#       CONTACT: stalin.stepin@outlook.com
#        GITHUB: https://github.com/stalin.stepin/nutanix-collectPerf
#       COMPANY:  NUTANIX
#       VERSION:  1.0
#       UPDATED:  24-04-2021
#          NOTE:  This script is not vetted by engineering team. Please use at own risk. 
#
#################################################################################################################

# Declaring variables.
printf "Configuring temporary variables. Please wait!!\n"
diskThreshold=80
# hardStop=1200 --> To be used later for hard stop the perf collection. 
homePartition='/dev/sda3'
homePath='/home/nutanix/data/performance'
stargatePath='/home/nutanix/data/stargate-storage/disks'
clusterID=$(ncli cluster info | grep -w 'Cluster Id' | awk -F':' '{print $NF}')


# Reading input from user in interactive mode. 
printf "\nEnter the number of iterations [INTEGER]: \n"
read -r numberOfIterations
printf "\n==================================================================\n"
df -kh | head -1 ; df -kh | grep stargate
printf "==================================================================\n"
printf "\nChoose serial number from one of the disk displayed above.\n"
printf "Example: $(df -kh | grep stargate | awk -F'/' '{print $NF}' | head -1) \n"
printf "Ensure to select the disk which has more available space:\n"
printf "\nEnter the disk serial number: \n"
read -r diskSerialNumber
printf "\nEnter the duration (in minutes) for how long each iteration should run [INTEGER]: \n"
read -r timeDuration
timeInSeconds=$(echo $((${timeDuration}*60)))
#timeInSeconds=$(echo $timeDuration*60)


# Creating directory for storing Perf data and logs.
perfDirectory=${stargatePath}/${diskSerialNumber}/perfData
mkdir "${perfDirectory}"
touch "${perfDirectory}"/perfDump.log
logFile=${perfDirectory}/perfDump.log
printf "\nPerf data dumped under: %s directory.\n" "${perfDirectory}" 
printf "Log is generated under: %s directory. \n" "${perfDirectory}"
printf "Log File name: perfDump.log\n" | tee -a "${logFile}"


# Checking if /home has sufficient space to collect perf stat collection. 
printf "\nChecking if '/home' has sufficient space to run the perf data collection!!! \n" | tee -a "${logFile}"
homeSpace=$(df -kh | grep "${homePartition}" | awk '{print $(NF-1)}' | awk -F'%' \{'print $1'\})
if [ "$homeSpace" -ge "$diskThreshold" ]
then
    printf "Exiting the script. '/home' space usage is more than 80 percentage.\n" | tee -a "${logFile}"
    df -kh | head -1 ; df -kh | grep "${homePartition}" | tee -a "${logFile}"
    printf "\nBring the space utilization under 80 percentage and retry again... \n" | tee -a "${logFile}"
    exit 1
else
    printf "Continuing... \n" | tee -a "${logFile}"
fi


# Collecting the perf stats, copying to stargate disks and performing cleanup. 
for (( i=1; i<="$numberOfIterations"; i++ ))
do
    printf "\n==================================================================\n"
    printf "Iteration %s:\n" "$i" | tee -a "${logFile}" 
    printf "\nProcess will be running for %s minutes. Starting perf stat collection now!!! \n" "${timeDuration}" | tee -a "${logFile}" 
    printf "TIMESTAMP: $(date) \n" | tee -a "${logFile}" 
    printf "==================================================================\n\n"
    collect_perf --sample_seconds=15 start | tee -a "${logFile}"
    sleep "$timeInSeconds"
    printf "==================================================================\n" 
    printf "\nStopping the perf collection. Please wait!!! \n" | tee -a "${logFile}" 
    printf "TIMESTAMP: $(date) \n\n" | tee -a "${logFile}" 
    collect_perf stop | tee -a "${logFile}"  
    response="$(echo $?)"

    if [ "${response}" -eq "0" ]
    then
        sleep 10
        printf "\nPerf collection process complete. \n"
        printf "Copying files to the data Directory. \n" | tee -a "${logFile}"
        #mv ${homePath}/cid-*_clusterid-"${clusterID}"_*.tgz  "${stargatePath}"/"${diskSerialNumber}"/ 
        mv ${homePath}/cid-*_clusterid-"${clusterID}"_*.tgz "${perfDirectory}" 
        $(cd ${homePath} || exit; rm -rf cid*_svm-*.tgz)
        printf "Perf files copied and cleanup completed. \n\n" | tee -a "${logFile}"
    fi
done

# Exiting script
printf "\nSuccessfully finished running program. Exiting script!!!\n\n" | tee -a "${logFile}"
exit 0

