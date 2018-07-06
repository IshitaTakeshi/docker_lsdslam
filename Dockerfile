FROM ubuntu:14.04

LABEL maintainer "NVIDIA CORPORATION <cudatools@nvidia.com>"

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates apt-transport-https gnupg-curl && \
    rm -rf /var/lib/apt/lists/* && \
    NVIDIA_GPGKEY_SUM=d1be581509378368edeec8c1eb2958702feedf3bc3d17011adbf24efacce4ab5 && \
    NVIDIA_GPGKEY_FPR=ae09fe4bbd223a84b2ccfce3f60f4b3d7fa2af80 && \
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/7fa2af80.pub && \
    apt-key adv --export --no-emit-version -a $NVIDIA_GPGKEY_FPR | tail -n +2 > cudasign.pub && \
    echo "$NVIDIA_GPGKEY_SUM  cudasign.pub" | sha256sum -c --strict - && rm cudasign.pub && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64 /" > /etc/apt/sources.list.d/cuda.list

ENV CUDA_VERSION 8.0.61

ENV CUDA_PKG_VERSION 8-0=$CUDA_VERSION-1
RUN apt-get update && apt-get install -y --no-install-recommends \
        cuda-nvrtc-$CUDA_PKG_VERSION \
        cuda-nvgraph-$CUDA_PKG_VERSION \
        cuda-cusolver-$CUDA_PKG_VERSION \
        cuda-cublas-8-0=8.0.61.2-1 \
        cuda-cufft-$CUDA_PKG_VERSION \
        cuda-curand-$CUDA_PKG_VERSION \
        cuda-cusparse-$CUDA_PKG_VERSION \
        cuda-npp-$CUDA_PKG_VERSION \
        cuda-cudart-$CUDA_PKG_VERSION && \
    ln -s cuda-8.0 /usr/local/cuda && \
    rm -rf /var/lib/apt/lists/*

# nvidia-docker 1.0
LABEL com.nvidia.volumes.needed="nvidia_driver"
LABEL com.nvidia.cuda.version="${CUDA_VERSION}"

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=8.0"


RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu trusty main" > /etc/apt/sources.list.d/ros-latest.list'
RUN apt-get update && apt-get install -y wget
RUN wget http://packages.ros.org/ros.key -O - | apt-key add -
RUN apt-get update && apt-get install -y ros-indigo-desktop-full
RUN rosdep init
RUN rosdep update
RUN apt-get update && apt-get install -y python-rosinstall

RUN mkdir -p /home/rosbuild_ws
WORKDIR /home/rosbuild_ws
RUN rosws init . /opt/ros/indigo
RUN mkdir package_dir
RUN rosws set -y /home/rosbuild_ws/package_dir -t .
RUN echo "source /home/rosbuild_ws/setup.bash" >> ~/.bashrc
RUN bash
WORKDIR package_dir
RUN apt-get update && apt-get install ros-indigo-libg2o ros-indigo-cv-bridge liblapack-dev libblas-dev freeglut3-dev libqglviewer-dev libsuitesparse-dev libx11-dev -y
RUN git clone https://github.com/tum-vision/lsd_slam.git
WORKDIR lsd_slam/lsd_slam_core/cfg
RUN sed -i -e "11,48s/'//g" LSDDebugParams.cfg
WORKDIR /home/rosbuild_ws/package_dir/lsd_slam/lsd_slam_viewer/cfg
RUN sed -i -e "20,24s/'//g" LSDSLAMViewerParams.cfg
WORKDIR /home/rosbuild_ws/package_dir/lsd_slam
RUN wget http://vmcremers8.informatik.tu-muenchen.de/lsd/LSD_room.bag.zip
RUN apt-get update && apt-get install -y unzip
RUN unzip LSD_room.bag.zip


RUN apt-get update && apt-get install -y \
	libopencv-dev build-essential checkinstall \
	cmake pkg-config yasm libtiff5-dev libjpeg-dev \
	libjasper-dev libavcodec-dev libavformat-dev \
	libswscale-dev libdc1394-22-dev libxine2-dev \
	libgstreamer0.10-dev libgstreamer-plugins-base0.10-dev \
	libv4l-dev python-dev python-numpy libtbb-dev libqt4-dev \
	libgtk2.0-dev libfaac-dev libmp3lame-dev libopencore-amrnb-dev \
	libopencore-amrwb-dev libtheora-dev libvorbis-dev libxvidcore-dev \
	x264 v4l-utils unzip
	
#RUN apt-get install -y git
	
RUN cd /home/${USERNAME} && mkdir opencv && cd opencv && \
	git clone https://github.com/Itseez/opencv.git && \
	cd opencv && git checkout tags/2.4.8 && \
	mkdir build && cd build && \
	cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local \
		-D WITH_TBB=ON -D BUILD_NEW_PYTHON_SUPPORT=ON -D WITH_V4L=ON \
		-D INSTALL_C_EXAMPLES=ON -D INSTALL_PYTHON_EXAMPLES=ON \
		-D BUILD_EXAMPLES=ON -D WITH_QT=ON -D WITH_OPENGL=ON .. && \
	make -j 4 && \
	make install && \
	sh -c 'echo "/usr/local/lib" > /etc/ld.so.conf.d/opencv.conf' && \
	ldconfig

RUN cd /home/rosbuild_ws/package_dir && \
	sed -i "/^#.*openFabMap/s/^#//" ./lsd_slam/lsd_slam_core/CMakeLists.txt && \
	sed -i "/^#.*FABMAP/s/^#//" ./lsd_slam/lsd_slam_core/CMakeLists.txt


WORKDIR /home/rosbuild_ws
RUN mv /bin/sh /bin/sh_tmp && ln -s /bin/bash /bin/sh
RUN echo 'PATH="$PATH:/path/to/pyenv"' >> ~/.bashrc
RUN source /home/rosbuild_ws/setup.bash && rosmake lsd_slam
RUN rm /bin/sh && mv /bin/sh_tmp /bin/sh

RUN apt-get update && apt-get install -y ros-indigo-usb-cam

#RUN echo "roscore &\
#	rosrun lsd_slam_viewer viewer &\
#	rosrun lsd_slam_core live_slam image:=/image_raw camera_info:=/camera_info &\
#	rosbag play /home/rosbuild_ws/package_dir/lsd_slam/LSD_room.bag" >> ~/.bashrc

COPY  camera.yaml /root/.ros/camera_info/head_camera.yaml
RUN echo "\
 	roscore &\
 	rosrun usb_cam usb_cam_node &\
 	rosrun lsd_slam_viewer viewer &\
 	rosrun lsd_slam_core live_slam image:=/usb_cam/image_raw camera_info:=/usb_cam/camera_info \
 	" >> ~/.bashrc

#COPY  bagbag.bag /home/rosbuild_ws/package_dir/lsd_slam/
#	rosrun lsd_slam_viewer viewer &\
#	rosrun lsd_slam_core live_slam image:=/image_raw camera_info:=/camera_info &\
#	rosbag play /home/rosbuild_ws/package_dir/lsd_slam/bagbag.bag" >> ~/.bashrc

