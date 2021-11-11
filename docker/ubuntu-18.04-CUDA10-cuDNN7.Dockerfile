ARG CUDA_VERSION=10.0.130
ARG CUDNN_VERSION=7.6.5
ARG OS_VERSION=18.04
ARG OS_ARCH=amd64

FROM ubuntu:18.04@sha256:fc0d6af5ab38dab33aa53643c4c4b312c6cd1f044c1a2229b2743b252b9689fc
# FROM nvidia/cuda:${CUDA_VERSION%.*}-cudnn7-devel-ubuntu${OS_VERSION}
LABEL maintainer="NVIDIA CORPORATION"

ENV TRT_VERSION 7.0.0.11
SHELL ["/bin/bash", "-c"]

# Setup user account
ARG uid=1000
ARG gid=1000
RUN groupadd -r -f -g ${gid} trtuser && useradd -o -r -u ${uid} -g ${gid} -ms /bin/bash trtuser
RUN usermod -aG sudo trtuser
RUN echo 'trtuser:nvidia' | chpasswd
RUN mkdir -p /workspace && chown trtuser /workspace

# Install requried libraries
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    wget \
    zlib1g-dev \
    git \
    pkg-config \
    sudo \
    ssh \
    gcc \
    vim \
    libssl-dev \
    pbzip2 \
    pv \
    bzip2 \
    unzip \
    devscripts \
    lintian \
    fakeroot \
    dh-make \
    build-essential

# Install python3
RUN apt-get install -y --no-install-recommends \
      python3 \
      python3-pip \
      python3-dev \
      python3-wheel &&\
    cd /usr/local/bin &&\
    ln -s /usr/bin/python3 python &&\
    ln -s /usr/bin/pip3 pip;


# Copy all deb + tar
# Download to host OS, put it in the same directory as this dockefile
# Nvidia download require credentials so no wget

# CUDA network repos
COPY cuda-repo-ubuntu1804_10.0.130-1_amd64.deb /

# cuDNN deb
COPY libcudnn7_7.6.5.32-1+cuda10.0_amd64.deb /
COPY libcudnn7-dev_7.6.5.32-1+cuda10.0_amd64.deb.deb /
COPY libcudnn7-doc_7.6.5.32-1+cuda10.0_amd64.deb /


# tensorRT
COPY TensorRT-7.0.0.11.Ubuntu-18.04.x86_64-gnu.cuda-10.0.cudnn7.6.tar.gz /

WORKDIR /


# CUDA, with network repos

# Install CUDA
RUN dpkg -i cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
RUN rm -rf cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
RUN apt-get update
RUN apt-get install cuda-10-0

# CUDA path
ENV PATH="/usr/local/cuda/bin:{$PATH}"

# CUDA 64 bit libs
# ALso the first LD_LIBRARY_PATH value
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64"


# Install cuDNN
RUN dpkg -i libcudnn7_7.6.5.32-1+cuda10.0_amd64.deb
RUN rm -rf libcudnn7_7.6.5.32-1+cuda10.0_amd64.deb
RUN dpkg -i libcudnn7-dev_7.6.5.32-1+cuda10.0_amd64.deb
RUN rm -rf libcudnn7-dev_7.6.5.32-1+cuda10.0_amd64.deb
RUN dpkg -i libcudnn7-doc_7.6.5.32-1+cuda10.0_amd64.deb
RUN rm -rf libcudnn7-doc_7.6.5.32-1+cuda10.0_amd64.deb


# Nvidia machine learning network repos
RUN wget https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/nvidia-machine-learning-repo-ubuntu1804_1.0.0-1_amd64.deb
RUN dpkg -i nvidia-machine-learning-repo-*.deb
RUN rm -rf nvidia-machine-learning-repo-ubuntu1804_1.0.0-1_amd64.deb
RUN apt-get update


# Install TensorRT
RUN v="${TRT_VERSION%.*}-1+cuda${CUDA_VERSION%.*}" &&\
    sudo apt-get install -y --no-install-recommends libnvinfer7=${v} libnvonnxparsers7=${v} libnvparsers7=${v} libnvinfer-plugin7=${v} \
        libnvinfer-dev=${v} libnvonnxparsers-dev=${v} libnvparsers-dev=${v} libnvinfer-plugin-dev=${v} \
        python-libnvinfer=${v} python3-libnvinfer=${v} python3-libnvinfer-dev=${v}

# Set TensorRT environment
ENV TRT_LIBPATH /usr/lib/x86_64-linux-gnu

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${TRT_LIBPATH}"

RUN tar -xzvf TensorRT-7.0.0.11.Ubuntu-18.04.x86_64-gnu.cuda-10.0.cudnn7.6.tar.gz
RUN cd TensorRT-7.0.0.11 && pip install graphsurgeon/graphsurgeon-0.4.1-py2.py3-none-any.whl \
    pip install uff/uff-0.6.5-py2.py3-none-any.whl
RUN mkdir -p /usr/local/TensorRT-7.0.0.11/bin
RUN mv TensorRT-7.0.0.11/bin/* /usr/local/TensorRT-7.0.0.11/bin/
RUN rm -rf TensorRT-7.0.0.11.Ubuntu-18.04.x86_64-gnu.cuda-10.0.cudnn7.6.tar.gz

# Install PyPI packages
RUN pip3 install --upgrade pip
RUN pip3 install setuptools>=41.0.0
# COPY requirements.txt /tmp/requirements.txt
# RUN pip3 install -r /tmp/requirements.txt
# RUN pip3 install jupyter jupyterlab


# Install Cmake
RUN cd /tmp && \
    wget https://github.com/Kitware/CMake/releases/download/v3.14.4/cmake-3.14.4-Linux-x86_64.sh && \
    chmod +x cmake-3.14.4-Linux-x86_64.sh && \
    ./cmake-3.14.4-Linux-x86_64.sh --prefix=/usr/local --exclude-subdir --skip-license && \
    rm ./cmake-3.14.4-Linux-x86_64.sh


# Copy NGC
COPY ngccli_linux.zip /usr/local/bin
WORKDIR /usr/local/bin

# Configure NGC
RUN cd /usr/local/bin && unzip ngccli_linux.zip && chmod u+x ngc && rm ngccli_linux.zip ngc.md5 && echo "no-apikey\nascii\n" | ngc config set

WORKDIR /


RUN ["/bin/bash"]