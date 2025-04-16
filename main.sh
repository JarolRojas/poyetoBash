#!/bin/bash

# COLORES
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
MORADO='\033[0;35m'
AZUL='\033[0;34m'
CYAN='\033[0;36m'
BLANCO='\033[1;37m'
GRIS='\033[0;37m'
SC='\033[0m'

# MOSTRAR MENU
opciones=("Gestión de seguridad" "Gestión de usuarios" "Gestión de red" "Administración del sistema" "Conexión remota" "Salir")

mostrarMenu() {
    echo -e "${ROJO}=== HERRAMIENTA DE ADMINISTRACIÓN DE SISTEMAS ==="
    for i in "${!opciones[@]}"; do
        echo -e "${VERDE}$((i + 1)). ${opciones[$i]}"
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
        sleep 0.1
    done
    sleep 1
    clear
}

# PREGUNTAR SI QUIERE SEGUIR
preguntarOtraAccion() {
    echo -en "${MORADO}¿Quieres realizar otra acción? (sí/[no]): ${AMARILLO}"
    read -r respuesta
    if [[ "$respuesta" == "sí" || "$respuesta" == "si" || "$respuesta" == "S" || "$respuesta" == "s" ]]; then
        clear
        return 0
    else
        return 1
    fi
}

# MAIN
while true; do
    clear
    mostrarMenu
    while true; do
        echo -en "${MORADO}Elige una opción: ${AMARILLO}"
        read -r opcion
        if [[ $opcion -ge 1 && $opcion -le ${#opciones[@]} ]]; then
            break
        else
            echo -e "${ROJO}Introduce una opción valida${SC}"
        fi
    done
    case $opcion in
    1)
        echo ""
        echo "Accediendo a Gestion de Seguridad..."
        barraCarga
        bash ./seguridad
        ;;
    2)
        echo ""
        echo "Accediendo a Gestion de Usuarios..."
        barraCarga
        bash ./usuarios
        ;;
    3)
        echo ""
        echo "Accediendo a Gestion de Red..."
        barraCarga
        sudo bash ./red
        ;;
    4)
        echo ""
        echo "Accediendo a Administracion del Sistema..."
        barraCarga
        bash ./administracion
        ;;
    5)
        echo ""
        echo "Accediendo a Conexion Remota..."
        barraCarga
        bash ./conexion
        ;;
    6)
        echo "\nSaliendo..."
        sleep 1
        clear
        exit
        ;;
    *)
        echo -e "${ROJO}Opción incorrecta${SC}"
        ;;
    esac
done
