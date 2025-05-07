#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "\n\033[1;31mPlease run as root:\033[0m sudo $0"
    exit 1
fi

# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Function to show saved WiFi passwords
show_passwords() {
    echo -e "\n${BLUE}Saved WiFi Networks:${NC}"
    echo -e "${BLUE}========================${NC}"
    
    # NetworkManager connections
    if command -v nmcli &> /dev/null; then
        echo -e "\n${YELLOW}NetworkManager Connections:${NC}"
        echo "--------------------------"
        nmcli -f NAME,UUID connection show | awk 'NR>1 {print $1}' | while read -r conn; do
            password=$(sudo nmcli -s connection show "$conn" | grep '802-11-wireless-security.psk:' | awk '{print $2}')
            if [ -n "$password" ]; then
                echo -e "${GREEN}$conn${NC}: ${RED}$password${NC}"
            else
                echo -e "${GREEN}$conn${NC}: No password stored"
            fi
        done
    else
        echo -e "${RED}NetworkManager (nmcli) not found!${NC}"
    fi
    
    # wpa_supplicant configs
    if [ -d "/etc/wpa_supplicant/" ]; then
        echo -e "\n${YELLOW}wpa_supplicant Configurations:${NC}"
        echo "----------------------------"
        grep -r 'ssid=\|psk=' /etc/wpa_supplicant/ 2>/dev/null | awk -F'=' '{
            if ($1 ~ /ssid/) {ssid=$2} 
            if ($1 ~ /psk/) {print "'${GREEN}'" ssid "'${NC}: ${RED}'" $2 "'${NC}'"}
        }' || echo "No wpa_supplicant configurations found"
    fi
    
    # System connections
    if [ -d "/etc/NetworkManager/system-connections/" ]; then
        echo -e "\n${YELLOW}System Connections:${NC}"
        echo "-----------------"
        find /etc/NetworkManager/system-connections/ -type f \( -name "*.nmconnection" -o -name "*" \) -exec grep -l 'ssid=\|psk=' {} \; 2>/dev/null | while read -r file; do
            ssid=$(grep '^ssid=' "$file" | cut -d= -f2-)
            password=$(grep '^psk=' "$file" | cut -d= -f2-)
            [ -n "$ssid" ] && [ -n "$password" ] && echo -e "${GREEN}$ssid${NC}: ${RED}$password${NC}"
        done
    fi
    
    echo -e "${BLUE}========================${NC}"
}

# Function to scan WiFi networks
scan_wifi() {
    echo -e "\n${BLUE}Scanning for available networks...${NC}"
    nmcli -f SSID,SECURITY,BARS device wifi list
}

# Function to connect to any WiFi network
connect_wifi() {
    while true; do
        echo -e "\n${BLUE}WiFi Connection Options${NC}"
        echo -e "${YELLOW}1. Scan and connect to visible network${NC}"
        echo -e "${YELLOW}2. Connect to hidden or non-visible network${NC}"
        echo -e "${YELLOW}3. Back to main menu${NC}"
        
        read -p "Enter choice [1-3]: " connect_choice
        
        case $connect_choice in
            1)
                scan_wifi
                read -p "Enter SSID to connect: " ssid
                read -s -p "Enter password: " password
                echo
                
                echo -e "\n${BLUE}Attempting to connect to $ssid...${NC}"
                nmcli device wifi connect "$ssid" password "$password"
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully connected to $ssid${NC}"
                else
                    echo -e "${RED}Failed to connect to $ssid${NC}"
                    echo "Possible reasons:"
                    echo "- Network is out of range"
                    echo "- Wrong password"
                    echo "- Network is actually hidden (try option 2)"
                fi
                ;;
            2)
                echo -e "\n${BLUE}Manual Network Setup${NC}"
                read -p "Enter exact SSID: " ssid
                read -s -p "Enter password: " password
                echo
                read -p "Security type [WPA2/WEP/none]: " security
                
                # Create new connection profile
                echo -e "\n${BLUE}Creating connection profile...${NC}"
                nmcli connection add type wifi con-name "$ssid" ssid "$ssid" > /dev/null 2>&1
                
                # Configure security
                case $security in
                    WPA2|wpa2)
                        nmcli connection modify "$ssid" wifi-sec.key-mgmt wpa-psk
                        nmcli connection modify "$ssid" wifi-sec.psk "$password"
                        ;;
                    WEP|wep)
                        nmcli connection modify "$ssid" wifi-sec.key-mgmt none
                        nmcli connection modify "$ssid" wifi-sec.wep-key0 "$password"
                        nmcli connection modify "$ssid" wifi-sec.auth-alg open
                        ;;
                    none)
                        nmcli connection modify "$ssid" wifi-sec.key-mgmt none
                        ;;
                    *)
                        echo -e "${YELLOW}Invalid security type, using WPA2${NC}"
                        nmcli connection modify "$ssid" wifi-sec.key-mgmt wpa-psk
                        nmcli connection modify "$ssid" wifi-sec.psk "$password"
                        ;;
                esac
                
                # Attempt connection
                echo -e "${BLUE}Attempting to connect...${NC}"
                nmcli connection up "$ssid"
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully connected to $ssid${NC}"
                else
                    echo -e "${RED}Failed to connect to $ssid${NC}"
                    echo "Possible reasons:"
                    echo "- Network is out of range"
                    echo "- Wrong security type or password"
                    echo "- Driver/hardware issues"
                fi
                ;;
            3)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Main menu
while true; do
    clear
    echo -e "\n${BLUE}Linux WiFi Manager${NC}"
    echo -e "${YELLOW}1. Show saved WiFi passwords${NC}"
    echo -e "${YELLOW}2. Connect to WiFi network${NC}"
    echo -e "${YELLOW}3. Exit${NC}"
    
    read -p "Enter choice [1-3]: " choice
    
    case $choice in
        1) 
            clear
            show_passwords 
            read -p "Press Enter to return to main menu..."
            ;;
        2) 
            clear
            connect_wifi 
            ;;
        3) 
            echo -e "\n${GREEN}Exiting...${NC}"
            exit 0 
            ;;
        *) 
            echo -e "\n${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
done
