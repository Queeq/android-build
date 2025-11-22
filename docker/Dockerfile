FROM ubuntu:22.04

# Environment variables for container paths
ENV SRC_DIR=/build/src \
    OUT_DIR=/build/out \
    ZIPS_DIR=/build/zips \
    KEYS_DIR=/build/keys \
    LOGS_DIR=/build/logs \
    MANIFESTS_DIR=/build/manifests \
    USE_CCACHE=1 \
    CCACHE_DIR=/build/ccache \
    CCACHE_SIZE=50G

# Install base packages
RUN apt -qq update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
      bc bison bsdmainutils build-essential ccache cgpt clang \
      curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick \
      kmod lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool \
      libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2-utils \
      lsof lzop maven openjdk-8-jdk openssh-server python-is-python3 pngcrush procps \
      rsync schedtool squashfs-tools unzip vim wget xdelta3 xsltproc yasm zip \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install the repo tool
RUN curl -s https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo && \
    chmod a+x /usr/local/bin/repo

# Create a non-root user for building
RUN useradd -m -s /bin/bash androidbuilder && \
    mkdir -p /home/androidbuilder/.ssh && \
    chown -R androidbuilder:androidbuilder /home/androidbuilder
    

# Set up SSH server
RUN mkdir -p /run/sshd && chmod 0755 /run/sshd
RUN sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
RUN chown androidbuilder:androidbuilder /etc/ssh/ssh_host_*_key
EXPOSE 2222

# Create build directory, keys directory, etc.
RUN mkdir -p /build && chown -R androidbuilder:androidbuilder /build

# Copy build scripts
COPY *.sh /
RUN chown androidbuilder /*.sh && chmod u+x /*.sh

# Switch to non-root user
USER androidbuilder

ENTRYPOINT ["/entrypoint.sh"]

