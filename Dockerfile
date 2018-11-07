FROM centos/systemd:latest

LABEL maintainer="oatkrittin@gmail.com"

ENV SLURM_VERSION=18.08.3
ENV MUNGE_VERSION=0.5.13
ENV LMOD_VERSION=7.8
ENV USER_DEV=ansible
ENV ROOT_HOME=/root
ENV ROOT_RPMS=/root/rpmbuild/RPMS/x86_64
ENV APPS_ROOT_PATH=/opt/apps
ENV MODULES_DIR=/home/modules

WORKDIR ${ROOT_HOME} 
# Create users, set up SSH keys (for MPI), add sudoers
# -r for system account, -s for route shell to none bash one, -m for make home.
# Explicitly state UID & GID for synchronsization across cluster 
RUN groupadd -r -g 982 slurm && \
    useradd -r -u 982 -g 982 -s /bin/false slurm && \
    useradd -u 3333 -ms /bin/bash $USER_DEV && \
    usermod -aG wheel $USER_DEV

# Add .ssh and correct permissions.
ADD bootstrap/${USER_DEV}/.ssh /home/${USER_DEV}/.ssh
RUN chown -R ${USER_DEV}:wheel /home/${USER_DEV} && \
    chmod 700 /home/${USER_DEV}/.ssh && \
    chmod 644 /home/${USER_DEV}/.ssh/* && \
    chmod 600 /home/${USER_DEV}/.ssh/id_rsa

# Install dependencies
# epel-repository
# Development Tools included gcc, gcc-c++, rpm-guild, git, svn, etc.
# bzip2-devel, openssl-devel, zlib-devel needed by munge
# readline-devel, openssl, perl-ExtUtils-MakeMaker, pam-devel, pmix-devel, mysql-devel, hwloc-devel needed by slurm
# lua-posix lua lua-filesystem lua-devel tcl needed by Lmod
# which needed by easybuild
# wget, net-tools, bind-tools(nslookup), telnet for debugging
RUN yum -y update && \
    yum -y groupinstall "Development Tools" && \
    yum -y install \
    wget \
    ntp \
    openssh-server \
    bzip2-devel \
    openssl-devel \
    zlib-devel \
    readline-devel \
    openssl \
    perl-ExtUtils-MakeMaker \
    hwloc-devel \
    pam-devel \
    mysql-devel \
    pmix-devel \
    which \
    net-tools \
    telnet \
    bind-utils \
    && \
    yum clean all && \
    rm -rf /var/cache/yum/*

RUN systemctl enable sshd && \
    systemctl enable ntpd

# Create user `munge`
RUN groupadd -g 983 munge && \
    useradd  -m -d /var/lib/munge -u 983 -g munge  -s /sbin/nologin munge

# Install munge
RUN wget https://github.com/dun/munge/releases/download/munge-${MUNGE_VERSION}/munge-${MUNGE_VERSION}.tar.xz && \
    rpmbuild -tb --clean munge-${MUNGE_VERSION}.tar.xz && \ 
    rpm -ivh ${ROOT_RPMS}/munge-${MUNGE_VERSION}-1.el7.x86_64.rpm \
        ${ROOT_RPMS}/munge-libs-${MUNGE_VERSION}-1.el7.x86_64.rpm \
        ${ROOT_RPMS}/munge-devel-${MUNGE_VERSION}-1.el7.x86_64.rpm && \
    rm -f munge-${MUNGE_VERSION}.tar.xz 

# Configure munge (for SLURM authentication)
ADD bootstrap/etc/munge/munge.key /etc/munge/munge.key
RUN chown munge:munge /var/lib/munge && \
    chown munge:munge /etc/munge/munge.key && \
    chown munge:munge /etc/munge && chmod 600 /var/run/munge && \
    chmod 755 /run/munge && \
    chmod 600 /etc/munge/munge.key && \
    systemctl enable munge

# Build Slurm-* rpm packages ready for variant to pick and install
RUN wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    rpmbuild -ta --clean slurm-${SLURM_VERSION}.tar.bz2 && \
    rm -f slurm-${SLURM_VERSION}.tar.bz2

RUN yum -y install epel-release && \
    yum -y install \
    lua-posix \
    lua \
    lua-filesystem \
    lua-devel \
    tcl \
    && \
    yum clean all && \
    rm -rf /var/cache/yum/*

# Install Lmod
RUN wget https://sourceforge.net/projects/lmod/files/Lmod-${LMOD_VERSION}.tar.bz2 && \
    tar -xvjf Lmod-${LMOD_VERSION}.tar.bz2 && \
    cd Lmod-${LMOD_VERSION} && \
    ./configure --prefix=${APPS_ROOT_PATH} && \
    make install && \
    ln -s ${APPS_ROOT_PATH}/lmod/lmod/init/profile        /etc/profile.d/z00_lmod.sh && \
    ln -s ${APPS_ROOT_PATH}/lmod/lmod/init/cshrc          /etc/profile.d/z00_lmod.csh && \
    rm -f ../Lmod-${LMOD_VERSION}.tar.bz2 
#ln -s ${APPS_ROOT_PATH}/lmod/lmod/init/profile.fish   /etc/fish/conf.d/z00_lmod.fish && \

# Create Modules user & Easybuild init script. Practices by dtu.dk
# https://wiki.fysik.dtu.dk/niflheim/EasyBuild_modules#installing-easybuild specify MODULES_HOME
RUN groupadd -g 984 modules && \
    mkdir -p $MODULES_DIR && \
    useradd -m -c "Modules user" -d $MODULES_DIR -u 984 -g modules -s /bin/bash modules && \
    chown -R modules:modules ${MODULES_DIR} && \
    chmod a+rx ${MODULES_DIR}
ADD bootstrap/etc/profile.d/z01_EasyBuild.sh /etc/profile.d/z01_EasyBuild.sh

VOLUME [ "/etc/slurm" ]

EXPOSE 22