# ROCm PyTorch Dockerfile
# Copyright (c) 2024 Advanced Micro Devices, Inc. All Rights Reserved.
# Author(s): srinivasan.subramanian@amd.com
#V1.1
ARG base_rocm_docker=amddcgpuce/rocm:6.2.0-ub22-ompi5-ucx17
FROM docker.io/${base_rocm_docker}
#FROM rocm:6.2.0-ub22-ompi5-ucx17

# Add rocm_version build arg to use in dockerbuild dir name
ARG rocm_version="6.2.0"

MAINTAINER srinivasan.subramanian@amd.com

# README - podman command line to build rocm-pytorch docker
# time podman build --no-cache --security-opt label=disable --build-arg base_rocm_docker=amddcgpuce/rocm:6.2.0-ub22-ompi5-ucx17 --build-arg rocm_version=6.2.0 -v $HOME:/workdir -t srinivamd/rocm-pytorch:py310_pyt240_0190_rocm620 -f rocm-ompi5-pytorch.Dockerfile `pwd`

# Labels
LABEL "com.amd.container.aisw.description"="Pytorch on Latest ROCm GA Release Container for Development"
LABEL "com.amd.container.aisw.gfxarch"="gfx908, gfx90a, gfx940, gfx941, gfx942, gfx1030"
LABEL "com.amd.container.aisw.python3.version"="3.10"

ARG PYTORCH_VERSION="rocm6.2_internal_testing"
LABEL "com.amd.container.aisw.torch.version"=${PYTORCH_VERSION}

ARG TORCHVISION_VERSION="v0.19.0"
LABEL "com.amd.container.aisw.torchvision.version"=${TORCHVISION_VERSION}

# NOTE: Update MAGMA version when newer release is available
ARG MAGMA_VERSION="v2.8.0"
LABEL "com.amd.container.aisw.magma.version"=${MAGMA_VERSION}

# Update MKL when newer release is available
ARG MKL_VERSION="2024.1.0"
LABEL "com.amd.container.aisw.mkl.version"=${MKL_VERSION}

ARG dockerbuild_dirname="pytorch.${PYTORCH_VERSION}.${TORCHVISION_VERSION}.${rocm_version}"


ENV MKLROOT="/usr/local"
ENV MAGMA_HOME="/usr/local/magma"
ENV PKG_CONFIG_PATH="${MAGMA_HOME}/pkgconfig:${PKG_CONFIG_PATH}"
ENV LIBRARY_PATH="${LIBRARY_PATH}:${MAGMA_HOME}/lib"
ENV LD_RUN_PATH="${LD_RUN_PATH}:${MAGMA_HOME}/lib"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${MAGMA_HOME}/lib"
ENV CPATH="${CPATH}:${MAGMA_HOME}/include"
ENV PYTORCH_ROCM_ARCH="gfx908;gfx90a;gfx940;gfx941;gfx942;gfx1030"

# limit parallel jobs to 8
ENV MAX_JOBS="8"

# Apply patch for aotriton attn_fwd and attn_bwd hack
#COPY patch.flash_api.hip.diff.txt /root/patch.flash_api.hip.diff.txt

RUN apt clean && \
    apt-get clean && \
    apt-get -y update --fix-missing --allow-insecure-repositories && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    wget && \
    cd $HOME && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 20 && \
    mkdir -p $HOME/dockerbuild/${dockerbuild_dirname}/ && \
    cd $HOME/dockerbuild/${dockerbuild_dirname} && \
    pip3 install --no-cache-dir cmake ninja  && \
    pip3 install --no-cache-dir mkl==${MKL_VERSION} mkl-devel==${MKL_VERSION} && \
    ln -s /usr/local/lib/libmkl_gf_lp64.so.2 /usr/local/lib/libmkl_gf_lp64.so && \
    ln -s /usr/local/lib/libmkl_gnu_thread.so.2 /usr/local/lib/libmkl_gnu_thread.so && \
    ln -s /usr/local/lib/libmkl_core.so.2 /usr/local/lib/libmkl_core.so && \
    ln -s /usr/local/lib/libmkl_tbb_thread.so.2 /usr/local/lib/libmkl_tbb_thread.so && \
    rm /etc/ld.so.cache && \
    ldconfig && \
    git clone https://bitbucket.org/icl/magma && \
    cd magma && \
    git checkout tags/${MAGMA_VERSION} && \
    git submodule update --init --recursive && \
    cp make.inc-examples/make.inc.hip-gcc-mkl make.inc && \
    sed -i -e "/LIBDIR.*ROCM_PATH.*MKLROOT/ s/$/ -L\$\(MKLROOT\)\/lib/" make.inc && \
    MKLROOT=/usr/local make lib/libmagma.so install && \
    cd $HOME && \
    cd $HOME/dockerbuild/${dockerbuild_dirname} && \
    git clone https://github.com/ROCm/pytorch && \
    cd pytorch && \
    git checkout ${PYTORCH_VERSION} && \
    git submodule update --init --recursive && \
    pip3 install --no-cache -r requirements.txt && \
    python3 tools/amd_build/build_amd.py && \
    PYTORCH_ROCM_ARCH="gfx908;gfx90a;gfx940;gfx941;gfx942;gfx1030" USE_ROCM=1 USE_CUDA=OFF CMAKE_VERBOSE_MAKEFILE=1 CMAKE_CXX_COMPILER=g++ CMAKE_C_COMPILER=gcc COMAKE_Fortran_COMPILER=gfortran python3 setup.py install && \
    cd $HOME && \
    rm /etc/ld.so.cache && \
    ldconfig && \
    cd $HOME/dockerbuild/${dockerbuild_dirname} && \
    git clone https://github.com/pytorch/vision.git && \
    cd vision && \
    git checkout tags/${TORCHVISION_VERSION} && \
    git submodule update --init --recursive && \
    PYTORCH_ROCM_ARCH="gfx908;gfx90a;gfx940;gfx941;gfx942;gfx1030" USE_ROCM=1 USE_CUDA=OFF CMAKE_VERBOSE_MAKEFILE=1 CMAKE_CXX_COMPILER=g++ CMAKE_C_COMPILER=gcc COMAKE_Fortran_COMPILER=gfortran python3 setup.py install && \
    cd $HOME && \
    rm /etc/ld.so.cache && \
    ldconfig && \
    hash -r && \
    pip3 list -v && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf $HOME/.cache

RUN locale-gen en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Default to a login shell
CMD ["bash", "-l"]


