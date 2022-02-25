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

# Variables #

LINK_WIKI="https://github.com/Ferks-FK/Pterodactyl-Docker/wiki"
DISPLAY_MENU=true

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
}

print_success() {
  echo ""
  echo -e "* ${GREEN}SUCCESS${RESET}: $1"
}

print_hint() {
  echo ""
  echo -e "* ${GREEN}HINT${RESET}: $1"
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
CYAN="\033[1;36m"
RESET="\e[0m"

inicial_menu() {
if [ "$DISPLAY_MENU" == true ]; then
echo
print_brake 70
echo -e "* Welcome to the ${GREEN}Pterodactyl-Docker${RESET} help menu"
echo "* Select a help option:"
echo -ne "
* ${GREEN}-l, -L${RESET}    List all commands for managing your containers
* ${GREEN}-m, -M${RESET}    Manage your existing containers
* ${GREEN}-w, -W${RESET}    Show link to official wiki
* ${GREEN}-q, -Q${RESET}    Quit help menu
"
DISPLAY_MENU=false
print_brake 70
fi
system_input "Help Menu"
read -r OPT
case "$OPT" in
  l|L)
    list_all_commands
  ;;
  m|M)
    DISPLAY_MENU=true
    manage_containers
  ;;
  w|W)
    show_wiki
  ;;
  q|Q)
    echo "Bye!"
    exit 1
  ;;
  *)
    print_error "Invalid Option!"
  ;;
esac
inicial_menu
}

list_all_commands() {
print_hint "Be inside the directory (${YELLOW}/var/pterodactyl${RESET}) to run these commands!"
echo -ne "
${GREEN}docker compose down${RESET}                                 Stop and remove containers and networks
${GREEN}docker compose up --build -d${RESET}                        Build and create the containers again
${GREEN}docker compose start${RESET}                                Starts all containers
${GREEN}docker compose restart${RESET}                              Restart all containers
${GREEN}docker compose stop${RESET}                                 Stop all containers
${GREEN}docker compose ps${RESET}                                   List all containers
${GREEN}docker compose exec ${CYAN}<service_name> <command>${RESET}        Execute a specific command into a container
"
inicial_menu
}

manage_containers() {
if [ "$DISPLAY_MENU" == true ]; then
echo
echo "* What would you like to make? "
echo -ne "
[${YELLOW}0${RESET}]    Back to the main menu
[${YELLOW}1${RESET}]    Start all containers
[${YELLOW}2${RESET}]    Stop all containers
[${YELLOW}3${RESET}]    Restart all containers
[${YELLOW}4${RESET}]    Stop and remove all containers (You won't lose any data)
[${YELLOW}5${RESET}]    Delete all containers, and remove all data (${YELLOW}You will lose everything when using this option, so make sure you have a backup!${RESET})
"
DISPLAY_MENU=false
fi
if [ -d "/var/pterodactyl" ]; then
    cd "/var/pterodactyl"
  else
    cd "/var/daemon"
fi
system_input "Manane System"
read -r OPT
case "$OPT" in
  0)
    clear
    DISPLAY_MENU=true
    inicial_menu
  ;;
  1)
    docker compose up -d
    if docker compose up -d; then
        print_success "All containers were started successfully!"
      else
        print_error "Something's gone wrong!"
    fi
  ;;
  2)
    docker compose stop
    if docker compose stop; then
        print_success "All containers have been stopped successfully!"
      else
        print_error "Something's gone wrong!"
    fi  
  ;;
  3)
    docker compose restart
    if docker compose restart; then
        print_success "All containers were successfully restarted!"
      else
        print_error "Something's gone wrong!"
    fi
  ;;
  4)
    docker compose down
    if docker compose down; then
        print_success "All containers were stopped and removed successfully!"
      else
        print_error "Something's gone wrong!"
    fi
    ;;
  5)
    docker compose down -v
    rm -rf /var/pterodactyl/data
    rm -rf /var/pterodactyl/configs/daemon/config.yml
    if docker compose down -v &>/dev/null; then
        print_success "All containers have been stopped and their data has been successfully deleted!"
      else
        print_error "Something's gone wrong!"
    fi
  ;;
  *)
    print_error "Invalid Option!"
  ;;
esac
manage_containers
}

show_wiki() {
echo -ne "
* WIKI: ${YELLOW}$(hyperlink "$LINK_WIKI")${RESET}
"
inicial_menu
}

# Exec Script #
inicial_menu