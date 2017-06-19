#!/bin/bash

CORE=`grep --count processor /proc/cpuinfo`
source build/envsetup.sh 
lunch msm8916_64-eng
make -j$CORE | tee log.txt
