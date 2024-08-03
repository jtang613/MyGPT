#!/bin/bash

# Define color and formatting codes
BOLD='\033[1m'
GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m' # No Color

gen_certs() {
  echo -e "${WHITE}${BOLD}Generating self-signed certificate and private key...${NC}"

  # Set variables
  COUNTRY="US"
  STATE="XX"
  LOCALITY="Gotham"
  ORGANIZATION="Wayne Enterprises"
  UNIT="Applied Sciences Division"
  COMMON_NAME="mygpt.local"

  mkdir -p certs
  # Generate certificate and private key
  openssl req -x509 -newkey rsa:2048 -nodes \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$UNIT/CN=$COMMON_NAME" \
    -out certs/fullchain.pem -keyout certs/privkey.pem -days 3650 2>&1 > /dev/null
  echo -e "${WHITE}${BOLD}Self-signed certificate and private key generated successfully!${NC}"
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --data[folder=PATH]        Path to the data directory."
    echo "  --drop                     Drop the compose project."
    echo "  -q, --quiet                Run script in headless mode."
    echo "  -h, --help                 Show this help message."
}

# Default values
headless=false
kill_compose=false

# Function to extract value from the parameter
extract_value() {
    echo "$1" | sed -E 's/.*\[.*=(.*)\].*/\1/; t; s/.*//'
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --data*)
            value=$(extract_value "$key")
            data_dir=${value:-"./mygpt-data"}
            ;;
        --drop)
            kill_compose=true
            ;;
        -q|--quiet)
            headless=true
            ;;
        -h|--help)
            usage
            exit
            ;;
        *)
            # Unknown option
            echo "Unknown option: $key"
            usage
            exit 1
            ;;
    esac
    shift # past argument or value
done

if [[ $kill_compose == true ]]; then
    docker compose down --remove-orphans
    echo -e "${GREEN}${BOLD}Compose project dropped successfully.${NC}"
    exit
else
    DEFAULT_COMPOSE_COMMAND="docker compose -f docker-compose.yaml"
    export MYGPT_DATA_DIR=$data_dir # Set MYGPT_DATA_DIR environment variable  
    if [[ -n $data_dir ]]; then
        export MYGPT_DATA_DIR=$data_dir # Set MYGPT_DATA_DIR environment variable  
    fi
    DEFAULT_COMPOSE_COMMAND+=" up -d"
    DEFAULT_COMPOSE_COMMAND+=" --remove-orphans"
    DEFAULT_COMPOSE_COMMAND+=" --force-recreate"
fi

# Recap of environment variables
echo
echo -e "${WHITE}${BOLD}Current Setup:${NC}"
echo -e "   ${GREEN}${BOLD}Data Folder:${NC} ${data_dir}"
echo

if [[ $headless == true ]]; then
    echo -ne "${WHITE}${BOLD}Running in headless mode... ${NC}"
    choice="y"
else
    # Ask for user acceptance
    echo -ne "${WHITE}${BOLD}Do you want to proceed with current setup? (Y/n): ${NC}"
    read -n1 -s choice
fi

echo

if [[ $choice == "" || $choice == "y" ]]; then
    # Create data directories
    mkdir -p ${MYGPT_DATA_DIR}/open-webui/
    mkdir -p ${MYGPT_DATA_DIR}/sdwebui/models/
    mkdir -p ${MYGPT_DATA_DIR}/sdwebui/outputs/
    mkdir -p ${MYGPT_DATA_DIR}/ollama/
    mkdir -p ${MYGPT_DATA_DIR}/nginx/

    # Create certs and copy HTTPS proxy config
    gen_certs
    cp ./certs ${MYGPT_DATA_DIR}/nginx/
    rm ./certs/*
    cp ./nginx_proxy.conf ${MYGPT_DATA_DIR}/nginx/

    # Build SD.Next image
    echo -e "${WHITE}${BOLD}Building Stable Diffusion API image...${NC}"
    docker build -f sd-dockerfile -t sdwebui:latest .
    echo -e "${WHITE}${BOLD}Done.${NC}"

    # Execute the command with the current user
    echo -e "${WHITE}${BOLD}Bringing up services...${NC}"
    eval "$DEFAULT_COMPOSE_COMMAND" &

    # Capture the background process PID
    PID=$!

    # Wait for the command to finish
    wait $PID

    echo
    # Check exit status
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${BOLD}Compose project started successfully.${NC}"
    else
        echo -e "${RED}${BOLD}There was an error starting the compose project.${NC}"
    fi
else
    echo "Aborted."
fi

echo
