###########################################################
# base tools and dependencies
###########################################################
FROM centos:7 as base

RUN yum makecache fast && \
    yum -y install \
    libtirpc \
    python3 \
    python3-libs \
    python3-pip \
    python3-setuptools \
    openssh-clients \
    openssl \
    ansible \
    zlib-devel \
    curl-devel \
    gettext \
    gcc \
    openssh-server \
    sudo && \
    yum -y update


###########################################################
# Getting latest version of terraform-docs
###########################################################
FROM golang:1.13 as terraform-docs

ARG versionTerraformDocs
ENV versionTerraformDocs=${versionTerraformDocs}

RUN GO111MODULE="on" go get github.com/segmentio/terraform-docs@${versionTerraformDocs}

###########################################################
# Getting latest version of tfsec
###########################################################
FROM golang:1.13 as tfsec

# to force the docker cache to invalidate when there is a new version
RUN env GO111MODULE=on go get -u github.com/liamg/tfsec/cmd/tfsec

###########################################################
# Getting latest version of Azure CAF Terraform provider
###########################################################
FROM golang:1.13 as azurecaf

ARG versionAzureCafTerraform
ENV versionAzureCafTerraform=${versionAzureCafTerraform}

# to force the docker cache to invalidate when there is a new version
ADD https://api.github.com/repos/aztfmod/terraform-provider-azurecaf/git/ref/tags/${versionAzureCafTerraform} version.json
RUN cd /tmp && \
    git clone https://github.com/aztfmod/terraform-provider-azurecaf.git && \
    cd terraform-provider-azurecaf && \
    go build -o terraform-provider-azurecaf

###########################################################
# Getting latest version of yaegashi/terraform-provider-msgraph
###########################################################
FROM golang:1.13 as msgraph

# to force the docker cache to invalidate when there is a new version
ADD https://api.github.com/repos/aztfmod/terraform-provider-azurecaf/git/ref/heads/master version.json
RUN cd /tmp && \
    git clone https://github.com/yaegashi/terraform-provider-msgraph.git && \
    cd terraform-provider-msgraph && \
    go build -o terraform-provider-msgraph


###########################################################
# Installing tools
###########################################################
FROM centos:7 as tools

# Arguments set during docker-compose build -b --build from .env file
ARG versionTerraform
ARG versionAzureCli
ARG versionKubectl
ARG versionTflint
ARG versionGit
ARG versionJq
ARG versionDockerCompose
ARG versionTfsec
ARG versionRover

ENV versionTerraform=${versionTerraform} \
    versionAzureCli=${versionAzureCli} \
    versionKubectl=${versionKubectl} \
    versionTflint=${versionTflint} \
    versionJq=${versionJq} \
    versionGit=${versionGit} \
    versionDockerCompose=${versionDockerCompose} \
    versionTfsec=${versionTfsec} \
    versionRover=${versionRover}
#
# Rover Version
#
RUN echo ${versionRover} > /usr/bin/version.txt
#
# Common libs
#
RUN echo "Installing common tools" && \
    yum -y install \
    which \
    openssl \
    make \
    zlib-devel \
    curl-devel \ 
    gettext \
    bzip2 \
    gcc \
    unzip && \
    yum -y update
#
# Install git from source code
#
RUN echo "Installing git ${versionGit}..." && \
    curl -sSL -o /tmp/git.tar.gz https://www.kernel.org/pub/software/scm/git/git-${versionGit}.tar.gz && \
    tar xvf /tmp/git.tar.gz -C /tmp && \
    cd /tmp/git-${versionGit} && \
    ./configure --exec-prefix="/usr" && \
    make -j && \
    make install && \
    which git
#
# Install Docker CE CLI.
#
RUN yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    yum -y install docker-ce-cli && \
    which docker
#
# Install Terraform
#
RUN echo "Installing terraform ${versionTerraform}..." && \
    curl -sSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_linux_amd64.zip 2>&1 && \
    unzip -d /usr/bin /tmp/terraform.zip && \
    chmod +x /usr/bin/terraform && \
    which terraform
#
# Install Docker-Compose - required to rebuild the rover from the rover ;)
#
RUN echo "Installing docker-compose ${versionDockerCompose}..." && \
    curl -L -o /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${versionDockerCompose}/docker-compose-Linux-x86_64" && \
    chmod +x /usr/bin/docker-compose && \
    which docker-compose
#
# Install Azure-cli
#
RUN echo "Installing azure-cli ${versionAzureCli}..." && \
    rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    sh -c 'echo -e "[azure-cli] \n\
    name=Azure CLI \n\
    baseurl=https://packages.microsoft.com/yumrepos/azure-cli \n\
    enabled=1 \n\
    gpgcheck=1 \n\
    gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo' && \
    cat /etc/yum.repos.d/azure-cli.repo && \
    yum -y install azure-cli-${versionAzureCli} && \
    which az
#
# Install kubectl
#
RUN echo "Installing kubectl ${versionKubectl}..." && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${versionKubectl}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    which kubectl
#
# Install Helm
#
RUN echo "Installing Helm 3 ..." && \
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash && \
    which helm
#
# Install jq
#
RUN echo "Installing jq ${versionJq}..." && \
    curl -L -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-${versionJq}/jq-linux64 && \
    chmod +x /usr/bin/jq && \
    which jq
#
# Install tflint
#
RUN echo "Installing tflint ..." && \
    curl -sSL -o /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/download/${versionTflint}/tflint_linux_amd64.zip && \
    unzip -d /usr/bin /tmp/tflint.zip && \
    chmod +x /usr/bin/tflint && \
    which tflint
#
# Install tmux
#
RUN echo "Installing tmux ..." && \
    yum -y install tmux && \
    which tmux
#
# Copy Scripts
#
RUN echo "Copying rover tool scripts ..."
COPY scripts /tmp/scripts
RUN mkdir -p /tmp/scripts/rover /tmp/scripts/sshd && \
    ls -lrt /tmp/scripts && \
    mv /tmp/scripts/banner.sh /tmp/scripts/rover/banner.sh && \
    mv /tmp/scripts/build_image.sh /tmp/scripts/rover/build_image.sh && \
    mv /tmp/scripts/buildargs.sh /tmp/scripts/rover/buildargs.sh && \
    mv /tmp/scripts/clone.sh /tmp/scripts/rover/clone.sh && \
    mv /tmp/scripts/functions.sh /tmp/scripts/rover/functions.sh && \
    mv /tmp/scripts/pre_requisites.sh /tmp/scripts/rover/pre_requisites.sh && \
    mv /tmp/scripts/rover.sh /tmp/scripts/rover/rover.sh && \
    mv /tmp/scripts/sshd.sh /tmp/scripts/rover/sshd.sh && \
    mv /tmp/scripts/sshd_config /tmp/scripts/sshd && \
    ls -lrt /tmp/scripts/rover && \
    ls -lrt /tmp/scripts/sshd
###########################################################
# CAF rover image
###########################################################
FROM base

# Arguments set during docker-compose build -b --build from .env file
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG SSH_PASSWD

ENV SSH_PASSWD=${SSH_PASSWD} \
    USERNAME=${USERNAME} \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/home/${USERNAME}/.terraform.cache/plugin-cache"

RUN touch /var/run/docker.sock && \
    chmod 666 /var/run/docker.sock && \
    #
    # Install pre-commit
    #
    echo "Installing pre-commit ..." && \
    python3 -m pip install pre-commit && \ 
    echo "Creating ${USERNAME} user..." && \
    groupadd -g 1001 docker && \
    useradd --uid $USER_UID -m -G docker ${USERNAME} && \
    mkdir -p /tf/rover /home/${USERNAME}/.vscode-server /home/${USERNAME}/.vscode-server-insiders /home/${USERNAME}/.ssh /home/${USERNAME}/.ssh-localhost /home/${USERNAME}/.azure /home/${USERNAME}/.terraform.cache /home/${USERNAME}/.terraform.cache/tfstates && \
    chown ${USER_UID}:${USER_GID} /home/${USERNAME}/.vscode-server* /home/${USERNAME}/.ssh /home/${USERNAME}/.ssh-localhost /home/${USERNAME}/.azure /home/${USERNAME}/.terraform.cache /home/${USERNAME}/.terraform.cache/tfstates  && \
    echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    # ssh server for Azure ACI
    rm -f /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_rsa_key /home/${USERNAME}/.ssh/ssh_host_ecdsa_key && \
    ssh-keygen -q -N "" -t ecdsa -b 521 -f /home/${USERNAME}/.ssh/ssh_host_ecdsa_key

# Add Community terraform providers
COPY --from=azurecaf /tmp/terraform-provider-azurecaf/terraform-provider-azurecaf /bin/
COPY --from=msgraph /tmp/terraform-provider-msgraph/terraform-provider-msgraph /bin/
COPY --from=tfsec /go/bin/tfsec /bin/
COPY --from=terraform-docs /go/bin/terraform-docs /bin/

# Add tools
COPY --from=tools /usr/bin/git /usr/bin/git
COPY --from=tools /usr/bin/docker /usr/bin/docker
COPY --from=tools /usr/bin/terraform /usr/bin/terraform
COPY --from=tools /usr/bin/docker-compose /usr/bin/docker-compose
COPY --from=tools /usr/bin/az /usr/bin/az
COPY --from=tools /usr/bin/kubectl /usr/bin/kubectl
COPY --from=tools /usr/local/bin/helm /usr/bin/helm
COPY --from=tools /usr/bin/jq /usr/bin/jq
COPY --from=tools /usr/bin/tflint /usr/bin/tflint
COPY --from=tools /usr/bin/tmux /usr/bin/tmux
COPY --from=tools /tmp/scripts/sshd/sshd_config /home/${USERNAME}/.ssh/sshd_config
COPY --from=tools /tmp/scripts/rover/ /tf/rover
COPY --from=tools /usr/bin/version.txt /tf/rover/version.txt

WORKDIR /tf/rover

RUN echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.bashrc && \
    mkdir -p /tf/caf && \
    chown -R ${USERNAME}:1000 /tf/rover /tf/caf /home/${USERNAME}/.ssh && \
    chmod +x /tf/rover/sshd.sh

USER ${USERNAME}

EXPOSE 22
CMD  ["/tf/rover/sshd.sh"]