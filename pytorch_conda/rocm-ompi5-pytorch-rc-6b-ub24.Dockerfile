# ROCm PyTorch Stable Version Dockerfile
# Copyright (c) 2024 Advanced Micro Devices, Inc. All Rights Reserved.
# Author(s): srinivasan.subramanian@amd.com
#V1.1
# Use aotriton 0.6b with PyTorch RC version
# Don't delete souces, keep for unit tests
#
#ARG base_rocm_docker=amddcgpuce/rocm:6.2.0-ub24-ompi5-ucx17
ARG base_rocm_docker=amddcgpuce/rocm:6.2.0-ub24-hipmagmav280
FROM docker.io/${base_rocm_docker}
#FROM rocm:6.2.0-ub24-hipmagmav280

# Add rocm_version build arg to use in dockerbuild dir name
ARG rocm_version="6.2.0"

MAINTAINER srinivasan.subramanian@amd.com

# README - podman command line to build rocm-pytorch docker
# time podman build --no-cache --security-opt label=disable --build-arg base_rocm_docker=amddcgpuce/rocm:6.2.0-ub24-hipmagmav280 --build-arg rocm_version=6.2.0 -v $HOME:/workdir -t amddcgpuce/rocm-pytorch:6.2.0-ub24-py310_pyt240_0190_rocm620 -f rocm-ompi5-pytorch.Dockerfile `pwd`

# Labels
LABEL "com.amd.container.aisw.description"="Stable Pytorch Version on Latest ROCm GA Release Container for Development"
LABEL "com.amd.container.aisw.gfxarch"="gfx908, gfx90a, gfx940, gfx941, gfx942, gfx1030"
LABEL "com.amd.container.aisw.python3.version"="3.10"

ARG PYTORCH_VERSION="v2.4.1-rc3"
LABEL "com.amd.container.aisw.torch.version"=${PYTORCH_VERSION}

ARG TORCHVISION_VERSION="v0.19.1-rc5"
LABEL "com.amd.container.aisw.torchvision.version"=${TORCHVISION_VERSION}

# ROCm AOTRITON version
ARG AOTRITON_VERSION="0.6b"

ARG dockerbuild_dirname="pytorch.${PYTORCH_VERSION}.${TORCHVISION_VERSION}.${rocm_version}"

ENV PYTORCH_ROCM_ARCH="gfx908;gfx90a;gfx940;gfx941;gfx942;gfx1030"

# limit parallel jobs to 8
ENV MAX_JOBS="8"

# Install AOTRITON under /opt/aotriton
ARG aotriton_install="/opt/aotriton"
ENV AOTRITON_INSTALLED_PREFIX=${aotriton_install}

# Install triton
ARG TRITON_VERSION="3.0.x"

# Set up env for aotriton install
ENV CPATH="${AOTRITON_INSTALLED_PREFIX}/include:${CPATH}"
ENV LIBRARY_PATH="${AOTRITON_INSTALLED_PREFIX}/lib:${LIBRARY_PATH}"
ENV LD_RUN_PATH="${AOTRITON_INSTALLED_PREFIX}/lib:${LD_RUN_PATH}"
ENV LD_LIBRARY_PATH="${AOTRITON_INSTALLED_PREFIX}/lib:${LD_LIBRARY_PATH}"

RUN apt clean && \
    apt-get clean && \
    apt-get -y update --fix-missing --allow-insecure-repositories && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    zstd \
    libzstd-dev \
    ninja-build \
    wget && \
    cd $HOME && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 20 && \
    mkdir -p $HOME/dockerbuild/${dockerbuild_dirname}/ && \
    cd $HOME/dockerbuild/${dockerbuild_dirname} && \
    pip3 install --no-cache-dir cmake ninja  && \
    cd $HOME && \
    cd $HOME/dockerbuild/${dockerbuild_dirname} && \
    git clone https://github.com/ROCm/aotriton && \
    cd aotriton && \
    git checkout tags/${AOTRITON_VERSION} && \
    git submodule update --init --recursive && \
    sed -i -e 's%^        # create build directories%        with open(triton_cache_path+"/llvm/llvm-49af6502-ubuntu-x64/lib/cmake/mlir/MLIRConfig.cmake", "r+") as mlirconfig:\n            filebuf = mlirconfig.read()\n            filebuf = filebuf.replace(r"""find_package(LLVM ${LLVM_VERSION} EXACT REQUIRED CONFIG""", r"""find_package(LLVM ${LLVM_VERSION} EXACT REQUIRED CONFIG PATHS "${MLIR_INSTALL_PREFIX}/lib/cmake/llvm" NO_DEFAULT_PATH""")\n            mlirconfig.seek(0)\n            mlirconfig.write(filebuf)\n            mlirconfig.truncate()\n        # create build directories%' third_party/triton/python/setup.py && \
    mkdir build && \
    cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=${aotriton_install} -DCMAKE_BUILD_TYPE=Release -DAOTRITON_NO_SHARED=ON -DAOTRITON_COMPRESS_KERNEL=OFF -DAOTRITON_GPU_BUILD_TIMEOUT=0 -G Ninja && \
    ninja install && \
    cd .. && \
    mkdir build.so && \
    cd build.so && \
    cmake .. -DCMAKE_INSTALL_PREFIX=${aotriton_install} -DCMAKE_BUILD_TYPE=Release -DAOTRITON_NO_SHARED=OFF -DAOTRITON_COMPRESS_KERNEL=OFF -DAOTRITON_GPU_BUILD_TIMEOUT=0 -G Ninja && \
    sed -i -e "s/libaotriton_v2.a/libaotriton_v2.so/" build.ninja && \
    sed -i -e "s#LINK_LIBRARIES = v2src/libaotriton_v2.so#LINK_LIBRARIES = -laotriton_v2  -lzstd\n  LINK_PATH = -L\${cmake_ninja_workdir}/v2src#" build.ninja && \
    sed -i -e "s/libaotriton_v2.a/libaotriton_v2.so/" v2src/cmake_install.cmake && \
    ninja install && \
    echo "${aotriton_install}/lib" | tee -a /etc/ld.so.conf.d/aotriton.conf && \
    rm -f /etc/ld.so.cache && \
    ldconfig && \
    cd $HOME && \
    cd $HOME/dockerbuild/${dockerbuild_dirname} && \
    git clone https://github.com/triton-lang/triton && \
    cd triton && \
    git checkout release/${TRITON_VERSION} && \
    git submodule update --init --recursive && \
    pip3 install --no-cache-dir ninja cmake wheel && \
    cd python && \
    python3 setup.py install && \
    cd $HOME && \
    cd $HOME/dockerbuild/${dockerbuild_dirname} && \
    git clone https://github.com/pytorch/pytorch && \
    cd pytorch && \
    git checkout tags/${PYTORCH_VERSION} && \
    git submodule update --init --recursive && \
    pip3 install --no-cache-dir -r requirements.txt && \
    sed -i -e '/Wno-unused-but-set-parameter/ a  target_compile_options_if_supported(test_api \"-Wno-error=nonnull\")' test/cpp/api/CMakeLists.txt && \
    sed -i -e '/Workaround for https:/ a  set_source_files_properties(src/UtilsAvx512.cc PROPERTIES COMPILE_FLAGS \"-Wno-error=maybe-uninitialized\")' third_party/fbgemm/CMakeLists.txt && \
    python3 tools/amd_build/build_amd.py && \
    sed -i -e "s#gtest_main#gtest_main /opt/rocm-6.2.0/lib/libhsa-runtime64.so /opt/rocm-6.2.0/lib/librocprofiler-register.so#" c10/hip/test/CMakeLists.txt && \
    PYTORCH_ROCM_ARCH="gfx908;gfx90a;gfx940;gfx941;gfx942;gfx1030" USE_ROCM=1 USE_CUDA=OFF CMAKE_VERBOSE_MAKEFILE=1 CMAKE_CXX_COMPILER=g++ CMAKE_C_COMPILER=gcc COMAKE_Fortran_COMPILER=gfortran python3 setup.py install && \
    cd $HOME && \
    rm -f /etc/ld.so.cache && \
    ldconfig && \
    cd $HOME/dockerbuild/${dockerbuild_dirname} && \
    git clone https://github.com/pytorch/vision.git && \
    cd vision && \
    git checkout tags/${TORCHVISION_VERSION} && \
    git submodule update --init --recursive && \
    sed -i -e "s/^    pytorch_dep,//" setup.py && \
    PYTORCH_ROCM_ARCH="gfx908;gfx90a;gfx940;gfx941;gfx942;gfx1030" USE_ROCM=1 USE_CUDA=OFF CMAKE_VERBOSE_MAKEFILE=1 CMAKE_CXX_COMPILER=g++ CMAKE_C_COMPILER=gcc COMAKE_Fortran_COMPILER=gfortran python3 setup.py install && \
    cd $HOME && \
    rm /etc/ld.so.cache && \
    ldconfig && \
    hash -r && \
    pip3 list -v && \
    rm -rf $HOME/dockerbuild && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf $HOME/.cache

RUN locale-gen en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Default to a login shell
CMD ["bash", "-l"]


