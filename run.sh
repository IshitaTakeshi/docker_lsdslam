#!/bin/bash

# if [ $# -ne 1 ]; then
#   exit 1
# fi

display_number=$(ps -ef | grep "Xquartz :\d" | grep -v xinit | awk '{ print $9; }')
ip=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')

echo ip = $ip
echo display number = $display_number

xhost + $ip

# --privileged option for debugging
docker run -it --rm \
    -e DISPLAY=$ip$display_number \
    -e QT_X11_NO_MITSHM=1 \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --name lsdslam \
    --privileged \
    lsdslam
