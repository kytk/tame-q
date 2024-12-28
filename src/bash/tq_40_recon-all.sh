#!/bin/bash

# Calculating SUVR of PMPBB3 PET
# Part 4. Recon-all of (realigned) MRI

# This script does recon-all for T1w image(s) in parallel.

# 18 Mar 2023 K.Nemoto

# For debugging
#set -x 


[ ! -d subjects ] && mkdir subjects
export SUBJECTS_DIR=$PWD/subjects

#Check OS
os=$(uname)

#Check number of cores (threads)
if [[ $os == "Linux" ]]; then
  ncores=$(nproc)
  mem=$(cat /proc/meminfo | grep MemTotal | awk '{ printf("%d\n",$2/1024/1024) }')
elif [[ $os == "Darwin" ]]; then 
  ncores=$(sysctl -n hw.ncpu)
  mem=$(sysctl -n hw.memsize | awk '{ print $1/1024/1024/1024 }')
else
  echo "Cannot detect your OS!"
  exit 1
fi
echo "logical cores: $ncores "
echo "memory: ${mem}GB "

#Set parameter for parallel processing
# if ncores=1, set maxrunnning=1
# if ncores>1, compare ncores and meory and 
# employ the smaller value
# set maxrunning as $ncores|$mem - 1

if [[ $ncores -eq 1 ]]; then
  maxrunning=1
elif [[ $ncores -le $mem ]]; then
  maxrunning=$(($ncores - 1))
else
  maxrunning=$(($mem - 1))
fi
echo "set maxrunning=${maxrunning}"


#copy fsaverage and {lr}h.EC_average to $SUBJECTS_DIR if they don't exsit
find $SUBJECTS_DIR -maxdepth 1 | egrep fsaverage$ > /dev/null
if [ $? -eq 1 ]; then
  cp -r $FREESURFER_HOME/subjects/fsaverage $SUBJECTS_DIR
fi

find $SUBJECTS_DIR -maxdepth 1 | egrep [lr]h.EC_average$ > /dev/null
if [ $? -eq 1 ]; then
  cp -r $FREESURFER_HOME/subjects/[lr]h.EC_average $SUBJECTS_DIR
fi

#recon-all
for f in *_t1w_r.nii*
do
  running=$(ps x | grep [b]in/recon-all | awk -F ' ' '{print $(NF-2)}' | sort | uniq | wc -l)
  echo "$(date): running = ${running}"
  
  while [ $running -ge $maxrunning ];
  do
    sleep 600
    running=$(ps x | grep [b]in/recon-all | awk -F ' ' '{print $(NF-2)}' | sort | uniq | wc -l)
  done

  # c[12]*.nii* , iy_*.nii*, or y_*.nii* are excluded
  if [[ $f == c[12]* ]] || [[ $f == iy_* ]] || [[ $f == y_* ]]; then
    continue
  else
    fsid=${f%_t1w_r.nii*}
    if [ ! -e ${SUBJECTS_DIR}/${fsid}/mri/aseg.mgz ]; then
      recon-all -i $f -s $fsid -all -qcache &
      #recon-all -i $f -s $fsid -autorecon1 & #for debugging
    else
      echo "recon-all is already done."
    fi
  fi
done

running=$(ps x | grep [b]in/recon-all | awk -F ' ' '{print $(NF-2)}' | sort | uniq | wc -l)
while [ ${running} -gt 0 ];
do
  echo "$(date): Wait for the end of all recon-all. running = ${running}"
  sleep 600
  running=$(ps x | grep [b]in/recon-all | awk -F ' ' '{print $(NF-2)}' | sort | uniq | wc -l)
done

exit
