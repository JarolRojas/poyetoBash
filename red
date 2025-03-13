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
opciones=("Listar interfaces" "Añadir interfaz" "Eliminar interfaz" "Modificar interfaz" "Encender/Apagar interfaz" "Monitorear red" "Diagnóstico de conectividad" "Salir")
mostrarMenu() {
    clear
    echo -e "${ROJO}=== GESTIONAR RED ==="
    for i in "${!opciones[@]}"; do
        echo -e "${VERDE}$((i + 1)). ${opciones[$i]}"
    done
    echo ""
}

pulsaFin() {
    echo -e "${SC}Presiona una tecla para continuar..."
    read -n 1 -s
    clear
}

# VALIDAR IP
validarIP() {
    local ip=$1
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]{1,2})$"

    if [[ $ip =~ $regex ]]; then
        local ipParte=$(echo $ip | cut -d'/' -f1)
        local mascaraParte=$(echo $ip | cut -d'/' -f2)

        IFS='.' read -r -a octetos <<<"$ipParte"
        for octeto in "${octetos[@]}"; do
            if ((octeto < 0 || octeto > 255)); then
                return 1
            fi
        done

        if ((mascaraParte < 0 || mascaraParte > 32)); then
            return 1
        fi
        return 0
    else
        return 1
    fi
}

# LISTAR INTERFACES
listarInterfaces() {
    echo -e "\n\nListado de todas las interfaces:"
    echo -e "${CYAN}Nombre\t\tIP/Máscara\t\tEstado${SC}"

    ip -o link show | awk '{
        iface = $2;
        gsub(/:/, "", iface);  # Elimina los dos puntos del nombre
        split($3, flags, ",");
        estado = "DOWN";
        for (i in flags) {
            if (flags[i] == "UP") {
                estado = "UP";
                break;
            }
        }
        print iface, estado;
    }' | while read -r iface estado; do

        if [[ "$estado" == "UP" ]]; then
            estado_color="${VERDE}activo${SC}"
        else
            estado_color="${ROJO}apagado${SC}"
        fi

        ips=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4}')

        if [[ -z "$ips" ]]; then
            printf "%-16s%-24s%b\n" "$iface" "Sin IP asignada" "$estado_color"
        else
            while IFS= read -r ip; do
                printf "%-16s%-24s%b\n" "$iface" "$ip" "$estado_color"
            done <<<"$ips"
        fi
    done

    echo "-------------------------------------------------"
}

# AÑADIR INTERFAZ
anadirInterfaz() {
    listarInterfaces
    echo -en "\n${MORADO}Introduce el nombre de la nueva interfaz (q para salir): ${AMARILLO}"
    read nombreInterfaz

    # Si el usuario escribe "q", se cancela el proceso
    if [[ "$nombreInterfaz" == "q" || "$nombreInterfaz" == "Q" ]]; then
        echo "Proceso cancelado."
        return
    fi

    while [[ -z "$nombreInterfaz" ]]; do
        echo -en "${MORADO}El nombre de la interfaz no puede estar vacío. Intenta nuevamente (o escribe 'q' para salir): ${AMARILLO}"
        read nombreInterfaz

        if [[ "$nombreInterfaz" == "q" || "$nombreInterfaz" == "Q" ]]; then
            echo "Proceso cancelado."
            return
        fi
    done

    # Verificar si la interfaz ya existe
    if ip a show "$nombreInterfaz" &>/dev/null; then
        echo "La interfaz '$nombreInterfaz' ya existe. Intenta con otro nombre."
        return
    fi

    # Solicitar la dirección IP (opcional)
    echo -en "${MORADO}Introduce la dirección IP/Máscara (opcional, presiona Enter para dejarlo vacío, o 'q' para salir): ${AMARILLO}"
    read ip

    if [[ "$ip" == "q" || "$ip" == "Q" ]]; then
        echo "Proceso cancelado."
        return
    fi

    if [[ -n "$ip" ]]; then
        if ! validarIP "$ip"; then
            echo "La IP/Máscara introducida no es válida. La interfaz no se creará."
            return
        fi
    fi

    # Crear la interfaz
    ip link add "$nombreInterfaz" type dummy
    echo -e "${SC}Interfaz '$nombreInterfaz' creada exitosamente."

    # Si se ha proporcionado una IP, asignarla
    if [[ -n "$ip" ]]; then
        ip addr add "$ip" dev "$nombreInterfaz"
        echo -e "${SC}Dirección IP asignada a '$nombreInterfaz'."
    fi

    echo -en "\n${SC}¿Deseas ver la lista actualizada de interfaces? (s/n): "
    read respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        listarInterfaces
    fi
}

# ELIMINAR INTERFAZ
eliminarInterfaz() {
    listarInterfaces

    echo -en "${MORADO}\nIngrese el nombre de la interfaz a eliminar (q para salir): ${AMARILLO}"
    read interfaz

    [[ "$interfaz" == "q" || "$interfaz" == "Q" ]] && return 0

    while [[ -z "$interfaz" ]]; do
        echo -e "${ROJO}Error: Debes ingresar un nombre de interfaz${SC}"
        echo -en "${MORADO}Ingrese el nombre de la interfaz a eliminar (q para salir): ${AMARILLO}"
        read interfaz
        [[ "$interfaz" == "q" || "$interfaz" == "Q" ]] && return 0
    done

    if ! ip link show "$interfaz" &>/dev/null; then
        echo -e "${ROJO}Error: La interfaz '$interfaz' no existe${SC}"
        read -n 1 -s -p "Presiona cualquier tecla para continuar..."
        return 1
    fi

    interfaces_protegidas=("lo" "eth0" "wlan0" "docker0")
    if [[ " ${interfaces_protegidas[@]} " =~ " ${interfaz} " ]]; then
        echo -e "${ROJO}Error: No se puede eliminar la interfaz protegida '$interfaz'${SC}"
        read -n 1 -s -p "Presiona cualquier tecla para continuar..."
        return 1
    fi

    read -p "¿Estás seguro de eliminar la interfaz '$interfaz'? [s/N]: " confirmar
    if [[ "$confirmar" =~ [Ss] ]]; then
        ip link delete dev "$interfaz"
        if [ $? -eq 0 ]; then
            echo -e "${VERDE}Interfaz '$interfaz' eliminada con éxito${SC}"
            read -p "¿Deseas reiniciar el servicio de red? [s/N]: " reiniciar
            if [[ "$reiniciar" =~ [Ss] ]]; then
                systemctl restart networking 2>/dev/null || systemctl restart NetworkManager 2>/dev/null
            fi
        else
            echo -e "${ROJO}Error: No se pudo eliminar la interfaz '$interfaz'${SC}"
        fi
    else
        echo "Eliminación cancelada"
    fi
    pulsaFin
}

# MODIFICAR INTERFAZ
modificarInterfaz() {
    listarInterfaces
    echo -e "\n${AMARILLO}Modificación de interfaz:${SC}"
    while true; do
        echo -ne "${MORADO}Ingrese el nombre de la interfaz a modificar (o 'q' para salir): ${AMARILLO}"
        read -r interfaz
        if [[ "$interfaz" == "q" || "$interfaz" == "Q" ]]; then
            echo -e "${SC}Saliendo de la modificación de interfaz..."
            sleep 1
            return 0
        fi
        if ip link show "$interfaz" &>/dev/null; then
            break
        else
            echo -e "${ROJO}La interfaz '$interfaz' no existe. Por favor, intente de nuevo.${SC}"
        fi
    done

    while true; do
        echo -ne "Ingrese la nueva IP/máscara para '$interfaz' (ej: 192.168.1.100/24) (o 'q' para salir): "
        read -r nueva_ip
        if [[ "$nueva_ip" == "q" || "$nueva_ip" == "Q" ]]; then
            echo "Saliendo de la modificación de interfaz."
            return 0
        fi
        if [[ "$nueva_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            break
        else
            echo -e "${ROJO}Formato de IP/máscara inválido. Intente de nuevo.${SC}"
        fi
    done

    if ! ip addr flush dev "$interfaz"; then
        echo -e "${ROJO}Error al eliminar las IP actuales de '$interfaz'.${SC}"
        return 1
    fi

    if ! ip addr add "$nueva_ip" dev "$interfaz"; then
        echo -e "${ROJO}Error al asignar la IP/máscara '$nueva_ip' a '$interfaz'.${SC}"
        return 1
    fi

    echo -e "\nInterfaz '$interfaz' actualizada con la IP/máscara: $nueva_ip"
    listarInterfaces
}

# Encender/Apagar interfaz
encenderApagarInterfaz() {
    listarInterfaces
    echo -e "\n${AMARILLO}Encender/Apagar Interfaz:${SC}"

    while true; do
        echo -ne "${MORADO}Ingrese el nombre de la interfaz (o 'q' para salir): ${AMARILLO}"
        read -r interfaz
        if [[ "$interfaz" == "q" || "$interfaz" == "Q" ]]; then
            echo -e "${SC}Saliendo de encender/apagar interfaz..."
            return 0
        fi
        if ip link show "$interfaz" &>/dev/null; then
            break
        else
            echo -e "${ROJO}La interfaz '$interfaz' no existe. Intente de nuevo.${SC}"
        fi
    done

    flags=$(ip -o link show "$interfaz" | awk '{print $3}')

    if [[ "$flags" == *UP* ]]; then
        echo -ne "La interfaz '$interfaz' está activa. ¿Desea apagarla? [s/N]: "
        read -r respuesta
        if [[ "$respuesta" =~ ^[Ss]$ ]]; then
            if ip link set dev "$interfaz" down; then
                echo -e "${VERDE}La interfaz '$interfaz' ha sido apagada.${SC}"
            else
                echo -e "${ROJO}Error al apagar la interfaz '$interfaz'.${SC}"
            fi
        else
            echo "Operación cancelada."
        fi
    else
        echo -ne "La interfaz '$interfaz' está apagada. ¿Desea encenderla? [s/N]: "
        read -r respuesta
        if [[ "$respuesta" =~ ^[Ss]$ ]]; then
            if ip link set dev "$interfaz" up; then
                echo -e "${VERDE}La interfaz '$interfaz' ha sido encendida.${SC}"
            else
                echo -e "${ROJO}Error al encender la interfaz '$interfaz'.${SC}"
            fi
        else
            echo "Operación cancelada."
        fi
    fi

    sleep 1
    listarInterfaces
}

# Monitorear red
monitorearRed() {
    listarInterfaces
    echo -e "\n${AMARILLO}Monitorear Red:${SC}"
    while true; do
        echo -ne "${MORADO}Ingrese el nombre de la interfaz a monitorear(o 'q' para salir): ${AMARILLO}"
        read -r interfaz
        if [[ "$interfaz" == "q" || "$interfaz" == "Q" ]]; then
            echo -e "${SC}Saliendo Monitorear Red..."
            return 0
        fi
        if ip link show "$interfaz" &>/dev/null; then
            break
        else
            echo -e "${ROJO}La interfaz '$interfaz' no existe. Intente de nuevo.${SC}"
        fi
    done
    echo -e "${SC}Cargando monitor..."
    sleep 1
    echo "Presiona CTRL + C para cerrar el proceso. (Espera)"
    sleep 3
    iftop -i $interfaz
}

diagnosticarRed() {
    listarInterfaces
    echo -e "\n${AMARILLO}Diagnóstico de conectividad:${SC}"

    while true; do
        echo -ne "${MORADO}Ingrese el nombre de la interfaz a diagnosticar (o 'q' para salir): ${AMARILLO}"
        read -r interfaz
        if [[ "$interfaz" == "q" || "$interfaz" == "Q" ]]; then
            echo -e "${SC}Saliendo del diagnóstico..."
            return 0
        fi
        if ip link show "$interfaz" &>/dev/null; then
            if ip link show "$interfaz" | grep -q "state DOWN"; then
                echo -e "${ROJO}La interfaz '$interfaz' está apagada. Enciéndala e intente nuevamente.${SC}"
                return 1
            fi
            break
        else
            echo -e "${ROJO}La interfaz '$interfaz' no existe. Intente de nuevo.${SC}"
        fi
    done

    echo -e "\n${AZUL}=== Diagnóstico de '$interfaz' ===${SC}"

    echo -e "\n${CYAN}1. Estado de la interfaz:${SC}"
    ip link show "$interfaz"

    echo -e "\n${CYAN}2. IP asignada:${SC}"
    ip -4 addr show dev "$interfaz" | grep inet || echo -e "${ROJO}No tiene IP asignada${SC}"

    echo -e "\n${CYAN}3. Tabla de rutas:${SC}"
    ip route show dev "$interfaz"

    echo -e "\n${CYAN}4. Prueba de ping (8.8.8.8 - Google DNS):${SC}"
    ping -c 4 -I "$interfaz" 8.8.8.8 && echo -e "${VERDE}Conectividad OK${SC}" || echo -e "${ROJO}Error en la conexión${SC}"

    echo -e "\n${CYAN}5. ARP Scan (detección de dispositivos en la red local):${SC}"
    arp-scan --interface="$interfaz" --localnet || echo -e "${ROJO}Error al ejecutar ARP Scan${SC}"

    echo -e "\n${CYAN}6. Estadísticas de paquetes (números de errores, colisiones, etc.):${SC}"
    ip -s link show "$interfaz"

    echo -e "\n${AZUL}=== Diagnóstico completado ===${SC}"
}

# MAIN
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ser ejecutado como root."
    exit 1
fi

while true; do
    mostrarMenu
    while true; do
        echo -en "${MORADO}Elige una opción: ${AMARILLO}"
        read -r opcion
        if [[ $opcion -ge 1 && $opcion -le ${#opciones[@]} ]]; then
            break
        else
            echo -e "${ROJO}Introduce una opción válida${SC}"
        fi
    done

    case $opcion in
    1)
        listarInterfaces
        pulsaFin
        ;;
    2)
        anadirInterfaz
        pulsaFin
        ;;
    3)
        eliminarInterfaz
        clear
        ;;
    4)
        modificarInterfaz
        pulsaFin
        ;;
    5)
        encenderApagarInterfaz
        pulsaFin
        ;;
    6)
        monitorearRed
        pulsaFin
        ;;
    7)
        diagnosticarRed
        pulsaFin
        ;;
    8)
        exit
        ;;
    *)
        echo -e "${ROJO}Opción incorrecta${SC}"
        ;;
    esac
done

# PARA INSTALAR
# sudo apt install arp-scan
# sudo apt install iftop
# sudo apt install bsdmainutils
# sudo apt install iproute2
