#!/bin/bash
#shellcheck source=/dev/null

set -e

########################################################
# 
#         Pterodactyl-AutoAddons Installation
#
#         Created and maintained by Ferks-FK
#
#            Protected by MIT License
#
########################################################

# Get the latest version before running the script #
get_release() {
curl --silent \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/Ferks-FK/Pterodactyl-Docker/releases/latest |
  grep '"tag_name":' |
  sed -E 's/.*"([^"]+)".*/\1/'
}

# Variables #
SCRIPT_RELEASE="$(get_release)"
SUPPORT_LINK="https://discord.gg/buDBbSGJmQ"
GITHUB_URL="https://raw.githubusercontent.com/Ferks-FK/Pterodactyl-Docker/$SCRIPT_RELEASE"
LINK_WIKI="https://github.com/Ferks-FK/Pterodactyl-Docker/wiki"
CONFIGURE_SSL=false

print_brake() {
  for ((n = 0; n < $1; n++)); do
    echo -n "#"
  done
  echo ""
}

print_warning() {
  echo ""
  echo -e "* ${YELLOW}WARNING${RESET}: $1"
  echo ""
}

print_error() {
  echo ""
  echo -e "* ${RED}ERROR${RESET}: $1"
  echo ""
}

print_success() {
  echo ""
  echo -e "* ${GREEN}SUCCESS${RESET}: $1"
  echo ""
}

print() {
  echo ""
  echo -e "* ${GREEN}$1 ${RESET}"
  echo ""
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

GREEN="\e[0;92m"
YELLOW="\033[1;33m"
RED='\033[0;31m'
RESET="\e[0m"

#### OS check ####

check_distro() {
  print "Detecting your OS..."
  sleep 2
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$(echo "$ID" | awk '{print tolower($0)}')
    OS_VER=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si | awk '{print tolower($0)}')
    OS_VER=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$(echo "$DISTRIB_ID" | awk '{print tolower($0)}')
    OS_VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    OS="debian"
    OS_VER=$(cat /etc/debian_version)
  elif [ -f /etc/SuSe-release ]; then
    OS="SuSE"
    OS_VER="?"
  elif [ -f /etc/redhat-release ]; then
    OS="Red Hat/CentOS"
    OS_VER="?"
  else
    OS=$(uname -s)
    OS_VER=$(uname -r)
  fi

  OS=$(echo "$OS" | awk '{print tolower($0)}')
  OS_VER_MAJOR=$(echo "$OS_VER" | cut -d. -f1)
}

check_compatibility() {
print "Checking if your system is compatible with the script..."
sleep 2

case "$OS" in
    debian)
        [ "$OS_VER_MAJOR" == "9" ] && SUPPORTED=true
        [ "$OS_VER_MAJOR" == "10" ] && SUPPORTED=true
        [ "$OS_VER_MAJOR" == "11" ] && SUPPORTED=true
    ;;
    ubuntu)
        [ "$OS_VER_MAJOR" == "18" ] && SUPPORTED=true
        [ "$OS_VER_MAJOR" == "20" ] && SUPPORTED=true
    ;;
    centos)
        [ "$OS_VER_MAJOR" == "7" ] && SUPPORTED=true
        [ "$OS_VER_MAJOR" == "8" ] && SUPPORTED=true
    ;;
    *)
        SUPPORTED=false
    ;;
esac

if [ "$SUPPORTED" == true ]; then
    print "$OS $OS_VER is supported!"
  else
    echo "$OS $OS_VER is not supported!"
    exit 1
fi
}

inicial_deps() {
print "Downloading packages required for FQDN validation..."

case "$OS" in
  debian | ubuntu)
    apt-get update -y && apt-get install -y dnsutils
  ;;
  centos)
    if [[ "$OS_VER_MAJOR" == "7" ]]; then
        yum update -y && yum install -y bind-utils
      elif [[ "$OS_VER_MAJOR" == "8" ]]; then
        dnf update -y && dnf install -y bind-utils
    fi
  ;;
esac
}

check_fqdn() {
print "Checking FQDN..."
sleep 2
IP="$(curl -s https://ipecho.net/plain ; echo)"
CHECK_DNS="$(dig +short @8.8.8.8 "$FQDN" | tail -n1)"
if [[ "$IP" != "$CHECK_DNS" ]]; then
    print_error "Your FQDN (${YELLOW}$FQDN${RESET}) is not pointing to the public IP (${YELLOW}$IP${RESET}), please make sure your domain is set correctly."
    echo -n "* Would you like to check again? (y/N): "
    read -r CHECK_DNS_AGAIN
    [[ "$CHECK_DNS_AGAIN" =~ [Yy] ]] && check_fqdn
    [[ "$CHECK_DNS_AGAIN" == [a-xA-X]* ]] && print_error "Installation aborted!" && exit 1
  else
    print_success "DNS successfully verified!"
fi
}

ask_ssl() {
echo -ne "* Would you like to configure ssl for your domain? (y/N): "
read -r CONFIGURE_SSL
if [[ "$CONFIGURE_SSL" == [Yy] ]]; then
    CONFIGURE_SSL=true
fi
}

configure_ssl() {
print "Creating SSL certificate for your domain..."
sleep 2

if [ -d "/etc/letsencrypt/live/$FQDN" ]; then
    print_warning "There is already an SSL certificate for this domain!"
  else
    cd "/var/daemon"
    sudo docker compose run --rm --service-ports certbot certonly -d "$FQDN"
fi
}

deps_debian() {
print "Installing dependencies for Debian ${OS_VER}"

mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins
chmod +x /usr/local/lib/docker/cli-plugins
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
apt-get install -y docker-ce docker-ce-cli
}

deps_ubuntu() {
print "Installing dependencies for Ubuntu ${OS_VER}"

mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins
chmod +x /usr/local/lib/docker/cli-plugins
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
apt-get install -y docker-ce docker-ce-cli
}

deps_centos() {
print "Installing dependencies for Centos ${OS_VER}"

mkdir -p ~/.docker/cli-plugins/
yum install -y yum-utils
curl -SL https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins
chmod +x /usr/local/lib/docker/cli-plugins
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager -y --enable docker-ce-nightly --now
yum install docker-ce docker-ce-cli
}

download_essencial_files() {
print "Downloading essencial files..."

mkdir -p /var/daemon \
/var/daemon/configs \
/var/daemon/configs/certs \
/var/daemon/configs/daemon \
/var/daemon/configs/letsencrypt \
/var/daemon/configs/letsencrypt/renewal-hooks \
/var/daemon/configs/letsencrypt/webroot \
/var/daemon/configs/letsencrypt/renewal-hooks/deploy \
/var/daemon/configs/letsencrypt/renewal-hooks/post \
/var/daemon/configs/letsencrypt/renewal-hooks/pre
curl -so /var/daemon/node-only.example.yml "$GITHUB_URL"/docker/node-only.example.yml
curl -so /var/daemon/configs/letsencrypt/cli.ini "$GITHUB_URL"/configs/cli.ini
}

configure_firewall() {
print "Configuring the firewall..."

case "$OS" in
  debian | ubuntu)
    apt-get install -qq -y ufw

    ufw allow ssh >/dev/null
    ufw allow http >/dev/null
    ufw allow https >/dev/null

    ufw --force enable
    ufw --force reload
    ufw status numbered | sed '/v6/d'
  ;;
  centos)
    yum update -y -q

    yum -y -q install firewalld >/dev/null

    systemctl --now enable firewalld >/dev/null

    firewall-cmd --add-service=http --permanent -q
    firewall-cmd --add-service=https --permanent -q
    firewall-cmd --add-service=ssh --permanent -q
    firewall-cmd --reload -q
  ;;
esac
}

configure_environment() {
print "Configuring the base file..."

cd "/var/daemon"

mv node-only.example.yml docker-compose.yml
}

create_docker_container() {
print "Creating the container with your settings..."
print_warning "This process may take a few minutes, please do not cancel it."
sleep 2

cd "/var/daemon"
sudo docker compose up --build -d
}

install_daemon() {
print "Starting installation, this may take a few minutes, please wait."
sleep 3

case "$OS" in
  debian | ubuntu)
    apt-get update -y && apt-get upgrade -y

    [ "$OS" == "ubuntu" ] && deps_ubuntu
    [ "$OS" == "debian" ] && deps_debian
  ;;
  centos)
    yum update -y && yum upgrade -y
    deps_centos
  ;;
esac

download_essencial_files
configure_environment
[ "$CONFIGURE_SSL" == true ] && configure_ssl
create_docker_container
configure_firewall
bye
}

main() {
# Check if the pterodactyl has already been installed #
if [ -d "/var/www/pterodactyl" ]; then
    print_error "You already have a pterodactyl on your machine, aborting..."
    exit 1
  elif [ -d "/var/daemon" ]; then
    print_warning "You have already used this script to install daemon docker, you cannot install it again."
    echo -e "* Running a help script..."
    bash <(curl -s "$GITHUB_URL"/help.sh)
fi

# Exec Check Distro #
check_distro

# Check if the OS is docker compatible #
check_compatibility

# Set FQDN for panel #
FQDN=""
while [ -z "$FQDN" ]; do
  echo -ne "* Set the Hostname/FQDN for node (${YELLOW}node.example.com${RESET}): "
  read -r FQDN
  [ -z "$FQDN" ] && print_error "FQDN cannot be empty"
done

# Install the packages to check FQDN and ask about SSL only if FQDN is a string #
if [[ "$FQDN" == [a-zA-Z]* ]]; then
  inicial_deps
  check_fqdn
  ask_ssl
fi

# Summary #
echo
print_brake 40
echo
echo -e "* Hostname/FQDN: $FQDN"
[ "$CONFIGURE_SSL" == true ] && echo -e "* Configure SSL: $CONFIGURE_SSL"
echo
print_brake 40
echo

# Confirm all the choices #
echo -n "* Initial settings complete, do you want to continue to the installation? (y/N): "
read -r CONTINUE_INSTALL
[[ "$CONTINUE_INSTALL" =~ [Yy] ]] && install_daemon
[[ "$CONTINUE_INSTALL" == [a-xA-X]* ]] && print_error "Installation aborted!" && exit 1
}

bye() {
print_brake 90
  echo
  echo -e "${GREEN}* The script has finished the installation process!${RESET}"

  [ "$CONFIGURE_SSL" == true ] && APP_URL="https://$FQDN"
  [ "$CONFIGURE_SSL" == false ] && APP_URL="http://$FQDN"
  echo -e "${GREEN}* This is the FQDN that you will use in your node configuration: ${YELLOW}$(hyperlink "$APP_URL")${RESET}"
  echo -e "${GREEN}* Thank you for using this script!"
  echo -e "* Support Group: ${YELLOW}$(hyperlink "$SUPPORT_LINK")${RESET}"
  print_warning "The script has installed your node, but it is not configured\nplease visit the wiki to configure it: ${YELLOW}$(hyperlink "$LINK_WIKI")${RESET}"
  print_brake 90
  echo
}

# Exec Script #
main