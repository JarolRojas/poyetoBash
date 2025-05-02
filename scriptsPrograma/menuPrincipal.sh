#!/bin/bash

# COLORES
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
MORADO='\033[0;35m'
AZUL='\033[0;34m'
CYAN='\033[0;36m'
BLANCO='\033[1;37m'
SC='\033[0m'

# MOSTRAR MENU
opciones=("Gestión de seguridad" "Gestión de usuarios" "Gestión de red" "Administración del sistema" "Conexión remota" "Salir")

mostrarMenu() {
    echo -e "${AZUL}=== MENÚ PRINCIPAL ===${SC}"
    for i in "${!opciones[@]}"; do
        echo -e "${VERDE}$((i + 1)). ${opciones[$i]}${SC}"
    done
    echo ""
}

# BARRA DE CARGA
barraCarga() {
    local total=40
    for ((i = 0; i <= total; i++)); do
        percent=$((i * 100 / total))
        filled=$(printf "%0.s#" $(seq 2 $i))
        empty=$(printf "%0.s-" $(seq 1 $((total - i))))
        echo -ne "\r[${VERDE}${filled}${SC}${empty}] ${AMARILLO}${percent}%${SC}"
        sleep 0.05
    done
    echo ""
}

# MAIN
while true; do
    clear
    mostrarMenu
    echo -en "${MORADO}Elige una opción: ${AMARILLO}"
    read -r opcion
    case $opcion in
    1)
        echo -e "${CYAN}Accediendo a Gestión de Seguridad...${SC}"
        barraCarga
        if [[ -f ./seguridad.sh ]]; then
            bash ./seguridad.sh
        else
            echo -e "${ROJO}El archivo 'seguridad.sh' no existe.${SC}"
        fi
        ;;
    2)
        echo -e "${CYAN}Accediendo a Gestión de Usuarios...${SC}"
        barraCarga
        if [[ -f ./usuarios.sh ]]; then
            bash ./usuarios.sh
        else
            echo -e "${ROJO}El archivo 'usuarios.sh' no existe.${SC}"
        fi
        ;;
    3)
        echo -e "${CYAN}Accediendo a Gestión de Red...${SC}"
        barraCarga
        if [[ -f ./red.sh ]]; then
            bash ./red.sh
        else
            echo -e "${ROJO}El archivo 'red.sh' no existe.${SC}"
        fi
        ;;
    4)
        echo -e "${CYAN}Accediendo a Administración del Sistema...${SC}"
        barraCarga
        if [[ -f ./adminSistemas.sh ]]; then
            bash ./adminSistemas.sh
        else
            echo -e "${ROJO}El archivo 'adminSistemas.sh' no existe.${SC}"
        fi
        ;;
    5)
        echo -e "${CYAN}Accediendo a Conexión Remota...${SC}"
        barraCarga
        if [[ -f ./remoto.sh ]]; then
            bash ./remoto.sh
        else
            echo -e "${ROJO}El archivo 'remoto.sh' no existe.${SC}"
        fi
        ;;
    6)
        echo -e "${AMARILLO}Saliendo del programa...${SC}"
        sleep 1
        clear
        exit
        ;;
    *)
        echo -e "${ROJO}Opción no válida. Por favor, elige una opción del 1 al ${#opciones[@]}.${SC}"
        ;;
    esac
    echo -e "${MORADO}Presiona Enter para volver al menú principal...${SC}"
    read -r
done
