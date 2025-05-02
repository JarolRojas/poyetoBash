#!/bin/bash
# filepath: ./install.sh

# Colores para la salida
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
SC='\033[0m'

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO}Este script debe ejecutarse como root.${SC}"
    exit 1
fi

echo -e "${AMARILLO}Actualizando el sistema...${SC}"
apt update && apt upgrade -y

echo -e "${AMARILLO}Instalando dependencias necesarias...${SC}"

# Instalar Zenity
echo -e "${VERDE}Instalando Zenity...${SC}"
apt install -y zenity

# Instalar Python3 y pip
echo -e "${VERDE}Instalando Python3 y pip...${SC}"
apt install -y python3 python3-pip

# Instalar mpstat (sysstat)
echo -e "${VERDE}Instalando sysstat (mpstat)...${SC}"
apt install -y sysstat

# Instalar ethtool
echo -e "${VERDE}Instalando ethtool...${SC}"
apt install -y ethtool

# Instalar ipcalc
echo -e "${VERDE}Instalando ipcalc...${SC}"
apt install -y ipcalc

# Instalar lynis
echo -e "${VERDE}Instalando Lynis...${SC}"
apt install -y lynis

# Instalar OpenSSH Server
echo -e "${VERDE}Instalando OpenSSH Server...${SC}"
apt install -y openssh-server

# Instalar UFW (Uncomplicated Firewall)
echo -e "${VERDE}Instalando UFW (Uncomplicated Firewall)...${SC}"
apt install -y ufw

# Instalar bibliotecas de Python necesarias
echo -e "${VERDE}Instalando bibliotecas de Python necesarias...${SC}"
pip install secure-smtplib

# Configurar permisos para los scripts
echo -e "${AMARILLO}Configurando permisos para los scripts...${SC}"
chmod +x ./scriptsPrograma/*.sh

# Finalización
echo -e "${VERDE}Instalación completada. Puedes ejecutar el programa desde 'menuPrincipal.sh'.${SC}"