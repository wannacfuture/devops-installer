GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
DOCKER_COMPOSE_VERSION="2.10.2"
TERRAFORM_VERSION="1.2.8"
PACKER_VERSION="1.8.3"
KIND_VERSION="0.11.1"
CRICTL_VERSION="v1.24.2"

function install_ansible() {
  echo -e "${YELLOW}Installing Ansible...${NC}"
  sudo apt -y remove needrestart
  sudo apt update -y
  sudo apt install software-properties-common -y
  sudo apt-add-repository -y --update ppa:ansible/ansible
  sudo apt install ansible -y
}

if ! [ -x "$(command -v ansible)" ]; then
  echo -e "${RED}Ansible is not installed.${NC}" >&2
  install_ansible
else 
  echo -e "${GREEN}Ansible is installed.${NC}"
  ansible=$(ansible --version | grep "core" | head -1)
  echo -e "${GREEN}Ansible version: $ansible${NC}"
fi

function install_docker() {
  echo -e "${YELLOW}Installing Docker...${NC}"
    sudo apt-get update --yes
    sudo apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository -y \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    sudo apt-get install -y docker-ce
    sudo usermod -aG docker $USER
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
}

if ! [ -x "$(command -v docker)" ]; then
  echo -e "${RED}Docker is not installed.${NC}" >&2
  install_docker
else 
  echo -e "${GREEN}Docker is installed.${NC}"
  docker=$(docker --version)
  echo -e "${GREEN}Docker version: $docker${NC}"
fi

function install_cri_dockerd() {
    echo -e "${YELLOW}Installing CRI-Dockerd...${NC}"
    wget https://storage.googleapis.com/golang/getgo/installer_linux
    chmod +x ./installer_linux
    ./installer_linux
    # source ~/.bash_profile
    sudo source root/.bash_profile
    git clone https://github.com/Mirantis/cri-dockerd.git
    cd cri-dockerd
    mkdir bin
    go build -o bin/cri-dockerd
    mkdir -p /usr/local/bin
    sudo install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
    sudo cp -a packaging/systemd/* /etc/systemd/system
    sudo sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
    sudo systemctl daemon-reload
    sudo systemctl enable cri-docker.service
    sudo systemctl enable --now cri-docker.socket
    sudo systemctl status cri-docker.socket | grep Active
}

if ! [ -x "$(command -v systemctl status cri-docker.socket)" ]; then
  echo -e "${RED}CRI-Dockerd is not installed.${NC}" >&2
  install_cri_dockerd
else 
  # echo -e "${GREEN}CRI-Dockerd is installed. CRI-Dockerd version:"
  printf "${GREEN}CRI-Dockerd is installed. CRI-Dockerd version: "
  echo "$(cri-dockerd --version)"
  # cridockerd=$(sudo cri-dockerd --version)
  # echo "${GREEN}CRI-Dockerd version: $cridockerd${NC}"
fi

function install_kubectl() {
  echo -e "${YELLOW}Installing Kubectl...${NC}"
  sudo apt-get update --yes
  sudo apt-get install -y apt-transport-https ca-certificates curl
  sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
  sudo apt-get update --yes
  sudo apt-get install -y kubectl
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
}

if [ "$(dpkg-query -W -f='${Status}' kubectl 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
  echo -e "${RED}Kubectl is not installed.${NC}" >&2
  install_kubectl
else 
  echo -e "${GREEN}Kubectl is installed.${NC}"
  kubectl=$(kubectl version --client --short)
  echo -e "${GREEN}Kubectl version: $kubectl${NC}"
fi

function install_helm() {
  echo -e "${YELLOW}Installing Helm...${NC}"
  curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
  sudo apt-get install apt-transport-https --yes
  echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  sudo apt-get update --yes
  sudo apt-get install helm --yes
}

if ! [ -x "$(command -v helm)" ]; then
  echo -e "${RED}Helm is not installed.${NC}" >&2
  install_helm
else 
  echo -e "${GREEN}Helm is installed.${NC}"
  helm=$(helm version --short)
  echo -e "${GREEN}Helm version: $helm${NC}"
fi

function install_terraform() {
  echo -e "${YELLOW}Installing Terraform...${NC}"
  sudo apt-get install -y unzip
  wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
  sudo mv terraform /usr/local/bin/
  rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
}

if ! [ -x "$(command -v terraform)" ]; then
  echo -e "${RED}Terraform is not installed.${NC}" >&2
  install_terraform
else 
  echo -e "${GREEN}Terraform is installed.${NC}"
  terraform=$(terraform version)
  echo -e "${GREEN}Terraform version: $terraform${NC}"
fi

function install_packer() {
  echo -e "${YELLOW}Installing Packer...${NC}"
  sudo apt-get install -y unzip
  wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
  unzip packer_${PACKER_VERSION}_linux_amd64.zip
  sudo mv packer /usr/local/bin/
  rm packer_${PACKER_VERSION}_linux_amd64.zip
}

if ! [ -x "$(command -v packer)" ]; then
  echo -e "${RED}Packer is not installed.${NC}" >&2
  install_packer
else 
  echo -e "${GREEN}Packer is installed.${NC}"
  packer=$(packer version)
  echo -e "${GREEN}Packer version: $packer${NC}"
fi

function install_kind() {
  echo -e "${YELLOW}Installing Kind...${NC}"
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/
}

if ! [ -x "$(command -v kind)" ]; then
  echo -e "${RED}Kind is not installed.${NC}" >&2
  install_kind
else 
  echo -e "${GREEN}Kind is installed.${NC}"
  kind=$(kind version)
  echo -e "${GREEN}Kind version: $kind${NC}"
fi

function install_kubectx() {
  echo -e "${YELLOW}Installing Kubectx...${NC}"
  curl -Lo ./kubectx https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx
  chmod +x ./kubectx
  sudo mv ./kubectx /usr/local/bin/
}

if ! [ -x "$(command -v kubectx)" ]; then
  echo -e "${RED}Kubectx is not installed.${NC}" >&2
  install_kubectx
else 
  echo -e "${GREEN}Kubectx is installed.${NC}"
#   kubectx has not version flag  
#   kubectx=$(kubectx --version)
#   echo -e "${GREEN}Kubectx version: $kubectx${NC}"
fi

function install_kubens() {
  echo -e "${YELLOW}Installing Kubens...${NC}"
  curl -Lo ./kubens https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens
  chmod +x ./kubens
  sudo mv ./kubens /usr/local/bin/
}

if ! [ -x "$(command -v kubens)" ]; then
  echo -e "${RED}Kubens is not installed.${NC}" >&2
  install_kubens
else 
#   kubens has not version flag  
#   kubens=$(kubens --version)
#   echo -e "${GREEN}Kubens version: $kubens${NC}"
  echo -e "${GREEN}Kubens is installed.${NC}"
fi

function install_minikube() {
  echo -e "${YELLOW}Installing Minikube...${NC}"
  sudo apt-get install -y conntrack
  sudo curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
  sudo dpkg -i minikube_latest_amd64.deb
  rm minikube_latest_amd64.deb
}

if ! [ -x "$(command -v minikube)" ]; then
  echo -e "${RED}Minikube is not installed.${NC}" >&2
  install_minikube
else 
  echo -e "${GREEN}Minikube is installed.${NC}"
  minikube=$(minikube version)
  echo -e "${GREEN}Minikube version: $minikube${NC}\n"
  echo -e "${GREEN}$(minikube status)"
fi

function install_crictl() {
  echo -e "${YELLOW}Installing Crictl...${NC}"
  wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRICTL_VERSION/crictl-$CRICTL_VERSION-linux-amd64.tar.gz
  sudo tar zxvf crictl-$CRICTL_VERSION-linux-amd64.tar.gz -C /usr/local/bin
  rm -f crictl-$CRICTL_VERSION-linux-amd64.tar.gz
}

if ! [ -x "$(command -v crictl)" ]; then
  echo -e "${RED}Crictl is not installed.${NC}" >&2
  install_crictl
else 
  echo -e "${GREEN}Crictl is installed.${NC}"
  crictl=$(crictl --version)
  echo -e "${GREEN}Crictl version: $crictl${NC}"
fi