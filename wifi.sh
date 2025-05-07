#!/bin/bash

# First Version

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

# Function to show saved WiFi passwords
show_passwords() {
    echo -e "\nSaved WiFi Networks:"
    echo "========================"
    
    # NetworkManager connections
    if command -v nmcli &> /dev/null; then
        echo -e "\nNetworkManager Connections:"
        echo "--------------------------"
        nmcli -f NAME,UUID connection show | awk 'NR>1 {print $1}' | while read -r conn; do
            password=$(sudo nmcli -s connection show "$conn" | grep '802-11-wireless-security.psk:' | awk '{print $2}')
            if [ -n "$password" ]; then
                echo "$conn: $password"
            fi
        done
    fi
    
    # wpa_supplicant configs
    if [ -d "/etc/wpa_supplicant/" ]; then
        echo -e "\nwpa_supplicant Configurations:"
        echo "----------------------------"
        grep -r 'ssid=\|psk=' /etc/wpa_supplicant/ | awk -F'=' '{
            if ($1 ~ /ssid/) {ssid=$2} 
            if ($1 ~ /psk/) {print ssid ": " $2}
        }'
    fi
    
    # System connections
    if [ -d "/etc/NetworkManager/system-connections/" ]; then
        echo -e "\nSystem Connections:"
        echo "-----------------"
        find /etc/NetworkManager/system-connections/ -type f -name "*.nmconnection" -exec grep -H 'ssid=\|psk=' {} \; | awk -F'=' '{
            if ($1 ~ /ssid/) {ssid=$2} 
            if ($1 ~ /psk/) {print ssid ": " $2}
        }'
    fi
    
    echo "========================"
}

# Function to connect to any WiFi network
connect_wifi() {
    echo -e "\nWiFi Connection Options"
    echo "1. Connect to visible network"
    echo "2. Connect to hidden or non-visible network"
    echo "3. Back to main menu"
    
    read -p "Enter choice [1-3]: " connect_choice
    
    case $connect_choice in
        1)
            echo -e "\nScanning for available networks..."
            nmcli device wifi list
            read -p "Enter SSID to connect: " ssid
            read -s -p "Enter password: " password
            echo
            
            nmcli device wifi connect "$ssid" password "$password"
            
            if [ $? -eq 0 ]; then
                echo "Successfully connected to $ssid"
            else
                echo "Failed to connect to $ssid"
                echo "Possible reasons:"
                echo "- Network is out of range"
                echo "- Wrong password"
                echo "- Network is actually hidden (try option 2)"
            fi
            ;;
        2)
            echo -e "\nManual Network Setup"
            read -p "Enter exact SSID: " ssid
            read -s -p "Enter password: " password
            echo
            read -p "Security type [WPA2/WEP/none]: " security
            
            # Create new connection profile
            nmcli connection add type wifi con-name "$ssid" ssid "$ssid" ifname wlan0
            
            # Configure security
            case $security in
                WPA2)
                    nmcli connection modify "$ssid" wifi-sec.key-mgmt wpa-psk
                    nmcli connection modify "$ssid" wifi-sec.psk "$password"
                    ;;
                WEP)
                    nmcli connection modify "$ssid" wifi-sec.key-mgmt none
                    nmcli connection modify "$ssid" wifi-sec.wep-key0 "$password"
                    nmcli connection modify "$ssid" wifi-sec.auth-alg open
                    ;;
                none)
                    nmcli connection modify "$ssid" wifi-sec.key-mgmt none
                    ;;
                *)
                    echo "Invalid security type, using WPA2"
                    nmcli connection modify "$ssid" wifi-sec.key-mgmt wpa-psk
                    nmcli connection modify "$ssid" wifi-sec.psk "$password"
                    ;;
            esac
            
            # Attempt connection
            nmcli connection up "$ssid"
            
            if [ $? -eq 0 ]; then
                echo "Successfully connected to $ssid"
            else
                echo "Failed to connect to $ssid"
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
            echo "Invalid option"
            ;;
    esac
}

# Main menu
while true; do
    echo -e "\nLinux WiFi Manager"
    echo "1. Show saved WiFi passwords"
    echo "2. Connect to WiFi network"
    echo "3. Exit"
    
    read -p "Enter choice [1-3]: " choice
    
    case $choice in
        1) show_passwords ;;
        2) connect_wifi ;;
        3) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
