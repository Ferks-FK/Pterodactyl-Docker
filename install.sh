#!/bin/bash
#shellcheck source=/dev/null
#shellcheck disable=SC2001

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

get_docker_release() {
curl --silent \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/docker/compose/releases/latest |
  grep '"tag_name":' |
  sed -E 's/.*"([^"]+)".*/\1/'
}

# Variables #
SCRIPT_RELEASE="$(get_release)"
DOCKER_COMPOSE="$(get_docker_release)"
SUPPORT_LINK="https://discord.gg/buDBbSGJmQ"
GITHUB_URL="https://raw.githubusercontent.com/Ferks-FK/Pterodactyl-Docker/$SCRIPT_RELEASE"
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

print_hint() {
  echo ""
  echo -e "* ${GREEN}HINT${RESET}: $1"
  echo ""
}

print() {
  echo ""
  echo -e "* ${GREEN}$1 ${RESET}"
  echo ""
}

system_input() {
echo ""
echo -ne "${GREEN}$1${RESET}> "
}

hyperlink() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

GREEN="\e[0;92m"
YELLOW="\033[1;33m"
RED='\033[0;31m'
RESET="\e[0m"

regex="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"

valid_email() {
  [[ $1 =~ ${regex} ]]
}

required_input() {
  local __resultvar=$1
  local result=''

  while [ -z "$result" ]; do
    echo -n "* ${2}"
    read -r result

    if [ -z "${3}" ]; then
      [ -z "$result" ] && result="${4}"
    else
      [ -z "$result" ] && print_error "${3}"
    fi
  done

  eval "$__resultvar="'$result'""
}

password_input() {
  local __resultvar=$1
  local result=''
  local default="$4"

  while [ -z "$result" ]; do
    echo -n "* ${2}"
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && {
        printf '\n'
        break
      }
      if [[ $char == $'\x7f' ]]; then
        if [ -n "$result" ]; then
          [[ -n $result ]] && result=${result%?}
          printf '\b \b'
        fi
      else
        result+=$char
        printf '*'
      fi
    done
    [ -z "$result" ] && [ -n "$default" ] && result="$default"
    [ -z "$result" ] && print_error "${3}"
  done

  eval "$__resultvar="'$result'""
}

email_input() {
  local __resultvar=$1
  local result=''

  while ! valid_email "$result"; do
    echo -n "* ${2}"
    read -r result

    valid_email "$result" || print_error "${3}"
  done

  eval "$__resultvar="'$result'""
}

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

check_processes() {
print "Checking to see if there are any services that could hurt the script..."
sleep 2

if [ "$(systemctl is-active --quiet nginx)" == "active" ]; then
        print_warning "It has been detected that you have installed the ${YELLOW}nginx${RESET} package, if it is active, it may hinder the script from completing the process."
        echo "Please shutdown this service, and run the script again."
        exit 1
    elif [ "$(systemctl is-active --quiet apache2)" == "active" ]; then
        print_warning "It has been detected that you have installed the ${YELLOW}apache2${RESET} package, if it is active, it may hinder the script from completing the process."
        echo "Please shutdown this service, and run the script again."
        exit 1
    elif [ "$(systemctl is-active --quiet httpd)" == "active" ]; then
        print_warning "It has been detected that you have installed the ${YELLOW}httpd${RESET} package, if it is active, it may hinder the script from completing the process."
        echo "Please shutdown this service, and run the script again."
        exit 1
    else
        print "No conflicting services found."
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
    cd "/var/pterodactyl"
    sudo docker-compose run --rm --service-ports certbot certonly -d "$FQDN"
fi
}

help_resources() {
echo
echo -e "You can choose how much processing (CPU) and memory (RAM)\nyou want to allocate to the containers."
echo
echo -e "* Examples:"
echo -e "
* ${GREEN}CPU${RESET}: 0.200% > 0.200% OF 1 CORE
* ${GREEN}CPU${RESET}: 0.400% > 0.400% OF 1 CORE
* ${GREEN}CPU${RESET}: 1.0% > 100% OF 1 CORE"
echo -e "
* ${GREEN}RAM${RESET}: 512MB > 512MB OF TOTAL RAM
* ${GREEN}RAM${RESET}: 1024MB > 1GB OF TOTAL RAM
* ${GREEN}RAM${RESET}: 2048MB > 2GB OF TOTAL RAM"
}

cpu_menu() {
print_hint "If you have questions, use the ${YELLOW}help${RESET} option."
echo -ne "* How much processing do you want to allocate to the containers?
1) 0.200% (${YELLOW}Default${RESET})
2) 0.400%
3) 0.600%
4) 0.800%
5) 1.0%
h) Help Menu"
echo
system_input "CPU"
read -r CPU
case "$CPU" in
  "" | 1)
      CPU="0.200"
      ;;
  2)
      CPU="0.400"
      ;;
  3)
      CPU="0.600"
      ;;
  4)
      CPU="0.800"
      ;;
  5)
      CPU="1.0"
      ;;
  h | H)
      help_resources
      cpu_menu
      ;;
  *)
      print_error "This option does not exist!"
      cpu_menu
      ;;
esac
}

ram_menu(){
echo -ne "* How much RAM do you want to allocate for the containers?
1) 512MB (${YELLOW}Default${RESET})
2) 1024MB
3) 2048MB
4) 3072MB
5) 4092MB"
echo
system_input "RAM"
read -r RAM
case "$RAM" in
"" | 1)
    RAM="512M"
    ;;
2)
    RAM="1024M"
    ;;
3)
    RAM="2048M"
    ;;
4)
    RAM="3072M"
    ;;
5)
    RAM="4092M"
    ;;
*)
    print_error "This option does not exist!"
    ram_menu
    ;;
esac
}

deps_debian() {
print "Installing dependencies for Debian ${OS_VER}"

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
apt-get install -y docker-ce docker-ce-cli
if ! docker-compose &>/dev/null; then
  curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi
}

deps_ubuntu() {
print "Installing dependencies for Ubuntu ${OS_VER}"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
apt-get install -y docker-ce docker-ce-cli
if ! docker-compose &>/dev/null; then
  curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi
}

deps_centos() {
print "Installing dependencies for Centos ${OS_VER}"

yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager -y --enable docker-ce-nightly --now
yum install docker-ce docker-ce-cli
if ! docker-compose &>/dev/null; then
  curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi
}

download_essencial_files() {
print "Downloading essencial files..."

mkdir -p /var/pterodactyl \
/var/pterodactyl/configs \
/var/pterodactyl/configs/certs \
/var/pterodactyl/configs/daemon \
/var/pterodactyl/configs/letsencrypt \
/var/pterodactyl/configs/letsencrypt/renewal-hooks \
/var/pterodactyl/configs/letsencrypt/webroot \
/var/pterodactyl/configs/letsencrypt/renewal-hooks/deploy \
/var/pterodactyl/configs/letsencrypt/renewal-hooks/post \
/var/pterodactyl/configs/letsencrypt/renewal-hooks/pre
curl -so /var/pterodactyl/docker-compose.example.yml "$GITHUB_URL"/docker/docker-compose.example.yml
curl -so /var/pterodactyl/configs/mariadb.env "$GITHUB_URL"/configs/mariadb.env
curl -so /var/pterodactyl/configs/panel.env "$GITHUB_URL"/configs/panel.env
curl -so /var/pterodactyl/configs/letsencrypt/cli.ini "$GITHUB_URL"/configs/cli.ini
}

configure_environment() {
print "Configuring the base file..."

cd "/var/pterodactyl"

sed -i -e "s@<ram>@$RAM@g" docker-compose.example.yml
sed -i -e "s@<cpu>@$CPU@g" docker-compose.example.yml
sed -i -e "s@<mysql_password>@$MYSQL_PASSWORD@g" configs/mariadb.env
sed -i -e "s@<mysql_password>@$MYSQL_PASSWORD@g" configs/panel.env
sed -i -e "s@<timezone>@$TIMEZONE@g" configs/panel.env
if [ "$CONFIGURE_SSL" == true ]; then
    sed -i -e "s@<cert>@/etc/letsencrypt/live/$FQDN/fullchain.pem@g" configs/panel.env
    sed -i -e "s@<cert_key>@/etc/letsencrypt/live/$FQDN/privkey.pem@g" configs/panel.env
    sed -i -e "s@<app_url>@https://$FQDN@g" configs/panel.env
  else
    sed -i -e "s@<cert>@/etc/certs/cert.pem@g" configs/panel.env
    sed -i -e "s@<cert_key>@/etc/certs/cert.key@g" configs/panel.env
    sed -i -e "s@<app_url>@http://$FQDN@g" configs/panel.env
fi
if [ "$FIRST_NODE" == true ]; then
    tr -d '#' < docker-compose.example.yml > docker-compose.example2.yml
    rm docker-compose.example.yml
    mv docker-compose.example2.yml docker-compose.example.yml
  else
    sed -i -e '95,116d' docker-compose.example.yml
fi

mv docker-compose.example.yml docker-compose.yml
}

create_user_login() {
print "Creating user access for the panel..."

docker-compose exec panel php artisan p:user:make \
  --email="$EMAIL" \
  --username="$USERNAME" \
  --name-first="$FIRSTNAME" \
  --name-last="$LASTNAME" \
  --password="$PASSWORD" \
  --admin=1
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

delete_unnecessary_files() {
print "Deleting unnecessary files..."

if [ -f "/var/pterodactyl/ready.txt" ]; then
  rm -r /var/pterodactyl/ready.txt
fi
if docker exec -it pterodactyl-panel-1 test -f ready.txt; then
  cd "/var/pterodactyl"
  sudo docker-compose exec panel rm ready.txt
fi
}

create_docker_container() {
print "Creating the container with your settings..."
print_warning "This process may take a few minutes, please do not cancel it."
sleep 2

cd "/var/pterodactyl"
sudo docker-compose up --build -d

while ! [ -f "/var/pterodactyl/ready.txt" ]; do
  sleep 2
  if docker exec -it pterodactyl-panel-1 test -f ready.txt; then
    docker cp pterodactyl-panel-1:/var/www/html/ready.txt /var/pterodactyl/ready.txt
  fi
done
configure_firewall
create_user_login
delete_unnecessary_files
bye
}

pre_config() {
echo -e "* What do you want to do?"
echo -ne "
1) First installation (${YELLOW}Installs pterodactyl and all necessary dependencies${RESET})
2) Install a new node (${YELLOW}Installs only a new node for an existing panel${RESET})
3) Exit
"
system_input "Inicial Choose"
read -r INICIAL_CHOOSE
case "$INICIAL_CHOOSE" in
  1)
    main
  ;;
  2)
    bash <(curl -s "$GITHUB_URL"/install_node.sh)
  ;;
  3)
    echo "Bye!"
    exit 1
  ;;
  *)
    print_error "Invalid Option!"
  ;;
esac
}

install_pterodactyl() {
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
}

main() {
# Check if the pterodactyl has already been installed #
if [ -d "/var/www/pterodactyl" ]; then
    print_error "You already have a pterodactyl on your machine, aborting..."
    exit 1
  elif [ -d "/var/pterodactyl" ]; then
    print_warning "You have already used this script to install pterodactyl docker, you cannot install it again."
    echo -e "* Running a help script..."
    bash <(curl -s "$GITHUB_URL"/help.sh)
fi

# Exec Check Distro #
check_distro

# Check if the OS is docker compatible #
check_compatibility

# Check if there are any conflicting processes active #
check_processes

# Set FQDN for panel #
FQDN=""
while [ -z "$FQDN" ]; do
  echo -ne "* Set the Hostname/FQDN for pterodactyl (${YELLOW}panel.example.com${RESET}): "
  read -r FQDN
  [ -z "$FQDN" ] && print_error "FQDN cannot be empty"
done

# Install the packages to check FQDN and ask about SSL only if FQDN is a string #
if [[ "$FQDN" == [a-zA-Z]* ]]; then
  inicial_deps
  check_fqdn
  ask_ssl
fi

# Ask which user to log into the panel #
echo -ne "* Username to login to your panel (${YELLOW}pterodactyl${RESET}): "
read -r USERNAME
[ -z "$USERNAME" ] && USERNAME="pterodactyl"

# Ask the user password to log into the panel #
password_input PASSWORD "Password for login to your panel: " "The password cannot be empty!"
password_input MYSQL_PASSWORD "Password for access to your mysql server: " "The password cannot be empty!"

# Ask the user for information #
email_input EMAIL "Email address for the initial admin account and letsencrypt: " "Email cannot be empty or invalid"
required_input FIRSTNAME "First name for the initial admin account: " "Name cannot be empty"
required_input LASTNAME "Last name for the initial admin account: " "Name cannot be empty"

# Ask Time-Zone #
echo -e "* List of valid time-zones here: ${YELLOW}$(hyperlink "http://php.net/manual/en/timezones.php")${RESET}"
echo -ne "* Select Time-Zone (${YELLOW}America/New_York${RESET}): "
read -r TIMEZONE
[ -z "$TIMEZONE" ] && TIMEZONE="America/New_York"

# Ask if you want to install a node #
echo -ne "* Would you like the script to install the first node for the panel? (y/N): "
read -r FIRST_NODE
if [[ "$FIRST_NODE" =~ [Yy] ]]; then
    FIRST_NODE=true
  else
    FIRST_NODE=false
fi

# Ask if the user wants to limit the container resources #
[[ "$FIRST_NODE" == true ]] && print_warning "These resource limits will not apply for the daemon containers."
echo -ne "* Would you like to limit the resources (CPU and RAM) of the containers that will be created? (y/N): "
CPU="0.200"
RAM="512M"
read -r RESOURCES
[[ "$RESOURCES" =~ [Yy] ]] && cpu_menu && ram_menu

# Summary #
echo
print_brake 75
echo
echo -e "* Pterodactyl Login: $USERNAME"
echo -e "* Pterodactyl Password: (censored)"
echo -e "* Hostname/FQDN: $FQDN"
[ "$CONFIGURE_SSL" == true ] && echo -e "* Email Certificate: $EMAIL"
[ "$CONFIGURE_SSL" == true ] && echo -e "* Configure SSL: $CONFIGURE_SSL"
echo -e "* Configure Firts Node: $FIRST_NODE"
echo -e "* Container CPU: $CPU%"
echo -ne "* Container RAM: $RAM"
echo "B"
echo
print_brake 75
echo

# Confirm all the choices #
echo -n "* Initial settings complete, do you want to continue to the installation? (y/N): "
read -r CONTINUE_INSTALL
[[ "$CONTINUE_INSTALL" =~ [Yy] ]] && install_pterodactyl
[[ "$CONTINUE_INSTALL" == [a-xA-X]* ]] && print_error "Installation aborted!" && exit 1
}

bye() {
  print_brake 70
  echo
  echo -e "${GREEN}* The script has finished the installation process!${RESET}"

  [ "$CONFIGURE_SSL" == true ] && APP_URL="https://$FQDN"
  [ "$CONFIGURE_SSL" == false ] && APP_URL="http://$FQDN"

  echo -e "${GREEN}* Your panel should be accessible through the link: ${YELLOW}$(hyperlink "$APP_URL")${RESET}"
  echo -e "${GREEN}* Thank you for using this script!"
  echo -e "* Support Group: ${YELLOW}$(hyperlink "$SUPPORT_LINK")${RESET}"
  echo
  print_brake 70
  echo
}

# Exec Script #
pre_config