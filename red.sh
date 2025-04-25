#!/bin/bash

# Colores
MORADO='\033[0;35m'
AMARILLO='\033[1;33m'
AMARILLO_CLARO='\033[0;93m'
ROJO='\033[0;31m'
ROJO_CLARO='\033[1;31m'
VERDE='\033[0;32m'
VERDE_CLARO='\033[1;32m'
AZUL='\033[0;34m'
AZUL_CLARO='\033[1;34m'
NARANJA='\033[0;33m'
NARANJA_CLARO='\033[1;33m'
CYAN='\033[0;36m'
BLANCO='\033[1;37m'
SC='\033[0m'
# Comprueba si el script se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO} Por favor, ejecuta este script como root."
    exit 1
fi

# Lisar opciones de menú
opciones=(
    "Listar interfaces disponibles"
    "Encender o apagar una interfaz"
    "Añadir una nueva interfaz de red"
    "Modificar una interfaz existente"
    "Eliminar una interfaz de red"
    "Probar conectividad (Ping)"
    "Monitorear actividad de una interfaz"
    "Diagnosticar problemas de red en una interfaz"
    "Validar IPs y calcular subredes"
    "Salir del menú de red"
)

# Funcion para mostrar menu
mostrarMenu() {
    echo -e "${VERDE}=== GESTIONAR RED ===\n\n${SC}"
    colores=("$MORADO" "$AMARILLO" "$VERDE" "$AZUL" "$CYAN" "$ROJO") # Patrón de colores
    for i in "${!opciones[@]}"; do
        color=${colores[$((i % ${#colores[@]}))]} # Alterna según el patrón
        echo -e "${color}$((i + 1)). ${opciones[$i]}${SC}\n"
    done
    echo ""
}

# Funcion para mostrar barra de carga
barraCarga() {
    local total=40
    for ((i = 0; i <= total; i++)); do
        percent=$((i * 100 / total))
        filled=$(printf "%0.s#" $(seq 1 $i))
        empty=$(printf "%0.s-" $(seq 1 $((total - i))))
        echo -ne "[${VERDE}${filled}${SC}${empty}] ${AMARILLO}${percent}%${SC}"
        sleep 0.1
    done
    sleep 1
    clear
}

pulsaFin() {
    echo -ne "\n${BLANCO}Presiona una tecla para continuar..."
    read -n 1 -s
    clear
}
#!/bin/bash

# Función que lista las interfaces con su IP y estado coloreado.
listar_interfaces() {
    # Definición de códigos ANSI para colores

    for iface in /sys/class/net/*; do
        name=$(basename "$iface")

        ip_address=$(ip -o -4 addr show "$name" | awk '{print $4}' | cut -d/ -f1)
        [[ -z "$ip_address" ]] && ip_address="N/A"

        state=$(cat "$iface/operstate")

        if [ "$state" == "up" ]; then
            color="$VERDE"
        else
            color="$ROJO_CLARO"
        fi

        printf "Interfaz: %-10s  IP: %-15s  Estado: ${color}%-4s${SC}\n" "$name" "$ip_address" "$state"
    done
}

apagar_interfaz() {
    local interfaz="$1"

    sudo ip link set "$interfaz" down

    if [[ $? -eq 0 ]]; then
        echo "Interfaz '$interfaz' apagada correctamente."
    else
        echo "Error al apagar la interfaz '$interfaz'."
    fi
}

encender_interfaz() {
    local interfaz="$1"

    sudo ip link set "$interfaz" up

    if [[ $? -eq 0 ]]; then
        echo "Interfaz '$interfaz' encendida correctamente."
    else
        echo "Error al encender la interfaz '$interfaz'."
    fi
}

encenderapagar_interfaz() {
    echo -e "${AMARILLO}Introduce el nombre de la interfaz que deseas encender o apagar: ${SC}"
    read -r interfaz
    if [[ -z "$interfaz" ]]; then
        echo -e "${ROJO}No se ha introducido ninguna interfaz.${SC}"
        return
    fi
    if [[ ! -d "/sys/class/net/$interfaz" ]]; then
        echo -e "${ROJO}La interfaz '$interfaz' no existe.${SC}"
        return
    fi
    estado=$(cat "/sys/class/net/$interfaz/operstate")
    if [[ "$estado" == "up" ]]; then
        echo -e "${AMARILLO}La interfaz '$interfaz' está actualmente encendida. ¿Deseas apagarla? (s/n) ${SC}"
        read -r respuesta
        if [[ "$respuesta" == "s" ]]; then
            apagar_interfaz "$interfaz"
        else
            echo -e "${VERDE}Operación cancelada.${SC}"
        fi
    else
        echo -e "${AMARILLO}La interfaz '$interfaz' está actualmente apagada. ¿Deseas encenderla? (s/n) ${SC}"
        read -r respuesta
        if [[ "$respuesta" == "s" ]]; then
            encender_interfaz "$interfaz"
        else
            echo -e "${VERDE}Operación cancelada.${SC}"
        fi
    fi
}

# Función para validar una IP con máscara (ejemplo: 12.12.12.12/12)
validar_ip_mascara() {
    local ip_mascara="$1"

    # Separar IP y máscara
    local ip=$(echo "$ip_mascara" | cut -d'/' -f1)
    local mascara=$(echo "$ip_mascara" | cut -d'/' -f2)

    # Validar formato de la IP (cuatro octetos separados por puntos)
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Formato de IP inválido ($ip)."
        return 1
    fi

    # Validar cada octeto de la IP (0-255)
    IFS='.' read -r oct1 oct2 oct3 oct4 <<<"$ip"
    for octeto in $oct1 $oct2 $oct3 $oct4; do
        if [[ -z "$octeto" || "$octeto" -gt 255 || "$octeto" -lt 0 ]]; then
            echo "Error: Octeto inválido ($octeto) en la IP."
            return 1
        fi
    done

    # Validar la máscara (0-32)
    if [[ ! "$mascara" =~ ^[0-9]+$ || "$mascara" -gt 32 || "$mascara" -lt 0 ]]; then
        echo "Error: Máscara de subred inválida ($mascara). Debe estar entre 0 y 32."
        return 1
    fi

    echo "La IP con máscara ($ip_mascara) es válida."
    return 0
}

anadir_interfaz() {
    echo -e "${AMARILLO}Introduce el nombre de la nueva interfaz: ${SC}"
    read -r nombre_interfaz
    if [[ -z "$nombre_interfaz" ]]; then
        echo -e "${ROJO}No se ha introducido ningún nombre.${SC}"
        return
    fi
    if [[ -d "/sys/class/net/$nombre_interfaz" ]]; then
        echo -e "${ROJO}La interfaz '$nombre_interfaz' ya existe.${SC}"
        return
    fi
    ip link add name "$nombre_interfaz" type dummy
    if [[ $? -ne 0 ]]; then
        echo -e "${ROJO}Error al crear la interfaz '$nombre_interfaz'.${SC}"
        return
    fi
    echo -e "${AMARILLO}¿Deseas asignar una dirección IP a la interfaz? (s/n) ${SC}"
    read -r respuesta
    if [[ "$respuesta" != "s" ]]; then
        echo -e "${VERDE}Interfaz '$nombre_interfaz' añadida correctamente sin IP.${SC}"
        return
    fi
    echo -e "Introduce la dirección IP con máscara para la interfaz ${nombre_interfaz} (ej. 192.168.1.1/24): ${SC}"
    read -r ip
    if [[ -z "$ip" ]]; then
        echo -e "${ROJO}No se ha introducido ninguna IP.${SC}"
        echo -e "${VERDE}La interfaz '$nombre_interfaz' se ha creado sin IP.${SC}"
        return
    fi
    validar_ip_mascara "$ip"
    if [[ $? -ne 0 ]]; then
        return
    fi
    ip addr add "$ip" dev "$nombre_interfaz"
    if [[ $? -ne 0 ]]; then
        echo -e "${ROJO}Error al asignar la IP '$ip' a la interfaz '$nombre_interfaz'.${SC}"
        return
    fi
    ip link set "$nombre_interfaz" up
    if [[ $? -ne 0 ]]; then
        echo -e "${ROJO}Error al activar la interfaz '$nombre_interfaz'.${SC}"
        return
    fi
    echo -e "${VERDE}Interfaz '$nombre_interfaz' añadida y activada correctamente con la IP '$ip'.${SC}"
}

modificar_interfaz() {
    echo "Introduce el nombre de la interfaz a modificar: "
    read -r nombre_interfaz
    if [[ -z "$nombre_interfaz" ]]; then
        echo "No se ha introducido ningún nombre."
        return
    fi
    if [[ ! -d "/sys/class/net/$nombre_interfaz" ]]; then
        echo "La interfaz '$nombre_interfaz' no existe."
        return
    fi
    echo "Introduce la nueva dirección IP con máscara (ej. 192.168.1.1/24): "
    read -r nueva_ip
    if [[ -z "$nueva_ip" ]]; then
        echo "No se ha introducido ninguna IP."
        return
    fi
    validar_ip_mascara "$nueva_ip"
    if [[ $? -ne 0 ]]; then
        echo "La IP con máscara '$nueva_ip' no es válida."
        return
    fi
    ip addr change "$nueva_ip" dev "$nombre_interfaz"
    if [[ $? -ne 0 ]]; then
        echo "Error al cambiar la IP de la interfaz '$nombre_interfaz'."
        return
    fi
    echo "IP de la interfaz '$nombre_interfaz' cambiada a '$nueva_ip' correctamente."
}
eliminar_interfaz() {
    echo -e "${AMARILLO}Introduce el nombre de la interfaz que deseas eliminar: ${SC}"
    read -r interfaz

    if [[ -z "$interfaz" ]]; then
        echo -e "${ROJO}No se ha introducido ninguna interfaz.${SC}"
        return
    fi

    if [[ ! -d "/sys/class/net/$interfaz" ]]; then
        echo -e "${ROJO}La interfaz '$interfaz' no existe.${SC}"
        return
    fi

    echo -e "${AMARILLO}¿Estás seguro de que deseas eliminar la interfaz '$interfaz'? (s/n) ${SC}"
    read -r respuesta

    if [[ "$respuesta" != "s" ]]; then
        echo -e "${VERDE}Operación cancelada.${SC}"
        return
    fi

    ip link set "$interfaz" down

    ip link delete "$interfaz"
    if [[ $? -eq 0 ]]; then
        echo -e "${VERDE}Interfaz '$interfaz' eliminada correctamente. ${SC}"
    else
        echo -e "${ROJO}Error al eliminar la interfaz '$interfaz'.${SC}"
    fi
}

probar_ping() {
    echo -e "\n${AMARILLO}Selecciona la interfaz desde la que deseas hacer el ping: ${SC}"
    read -r interfaz

    if [[ -z "$interfaz" ]]; then
        echo -e "${ROJO}No se ha introducido ninguna interfaz.${SC}"
        return
    fi
    if [[ ! -d "/sys/class/net/$interfaz" ]]; then
        echo -e "${ROJO}La interfaz '$interfaz' no existe.${SC}"
        return
    fi

    echo -e "${AMARILLO}Introduce la dirección IP o dominio que deseas pingear: ${SC}"
    read -r destino

    if [[ -z "$destino" ]]; then
        echo -e "${ROJO}No se ha introducido ningún host o IP.${SC}"
        return
    fi

    echo -e "${AZUL}Realizando ping a '$destino' desde '$interfaz' (4 paquetes)… ${SC}"
    if ping -I "$interfaz" -c 4 "$destino"; then
        echo -e "${VERDE}Ping completado con éxito desde '$interfaz'.${SC}"
    else
        echo -e "${ROJO}Fallo en la conectividad hacia '$destino' desde '$interfaz'.${SC}"
    fi
}
monitorear_interfaz() {
    echo -e "\n${AMARILLO}Selecciona la interfaz que deseas monitorear: ${SC}"
    read -r interfaz

    if [[ -z "$interfaz" ]]; then
        echo -e "${ROJO}No se ha introducido ninguna interfaz.${SC}"
        return
    fi
    if [[ ! -d "/sys/class/net/$interfaz" ]]; then
        echo -e "${ROJO}La interfaz '$interfaz' no existe.${SC}"
        return
    fi

    echo -e "${AZUL}Iniciando monitorización de la interfaz '$interfaz'… 🔍${SC}"
    echo -e "${AMARILLO}Presiona Ctrl+C para detener el monitoreo.${SC}\n"

    # Usamos watch para refrescar cada segundo el estado y estadísticas de la interfaz
        echo -e '${VERDE}Estado de la interfaz $interfaz:${SC}'
        clear
    watch -n 1 "ip -s link show $interfaz | sed -e '1,2d' -e 's/^/  /'"
}

diagnosticar_problemas_interfaz() {
 echo -e "\n${AMARILLO}Selecciona la interfaz que quieres diagnosticar: ${SC}"
    read -r interfaz

    if [[ -z "$interfaz" ]]; then
        echo -e "${ROJO}No se ha introducido ninguna interfaz.${SC}"
        return
    fi
    if [[ ! -d "/sys/class/net/$interfaz" ]]; then
        echo -e "${ROJO}La interfaz '$interfaz' no existe.${SC}"
        return
    fi

    echo -e "${AZUL}Iniciando diagnóstico de '$interfaz'… 🛠️${SC}\n"

    # 1) Estado operativo
    estado=$(cat "/sys/class/net/$interfaz/operstate")
    echo -e "${AMARILLO}Estado operativo:${SC} $estado"
    
    # 2) Velocidad y duplex con ethtool
    if command -v ethtool &> /dev/null; then
        echo -e "\n${AMARILLO}Detalle de enlace (ethtool):${SC}"
        ethtool "$interfaz" | awk '/Speed|Duplex|Link detected/'
    else
        echo -e "\n${ROJO}ethtool no está instalado. Omisión de detalle de enlace.${SC}"
    fi

    # 3) Estadísticas de paquetes y errores
    echo -e "\n${AMARILLO}Estadísticas RX/TX:${SC}"
    ip -s link show "$interfaz" | awk '
        NR==3 { printf "RX: bytes=%s packets=%s errors=%s dropped=%s\n", $1, $2, $3, $4 }
        NR==4 { printf "    missed=%s mcast=%s\n", $1, $2 }
        NR==6 { printf "TX: bytes=%s packets=%s errors=%s dropped=%s\n", $1, $2, $3, $4 }
        NR==7 { printf "    carrier=%s collsns=%s\n", $1, $2 }
    '

    # 4) Mensajes del kernel relacionados
    echo -e "\n${AMARILLO}Últimos mensajes del kernel para '$interfaz':${SC}"
    dmesg | grep -i "$interfaz" | tail -n 20 || echo -e "${ROJO}No hay mensajes recientes en dmesg.${SC}"

    # 5) Ping al gateway por la misma interfaz
    gateway=$(ip route | awk -v IF="$interfaz" '$1=="default" && $5==IF {print $3}')
    if [[ -n "$gateway" ]]; then
        echo -e "\n${AMARILLO}Ping al gateway ($gateway) desde '$interfaz':${SC}"
        ping -I "$interfaz" -c 4 "$gateway" && \
            echo -e "${VERDE}Conectividad al gateway OK.✅${SC}" || \
            echo -e "${ROJO}Fallo al pingear el gateway.⚠️${SC}"
    else
        echo -e "\n${ROJO}No se ha encontrado una ruta por defecto para '$interfaz'.${SC}"
    fi

    echo -e "\n${VERDE}Diagnóstico completado.${SC}"
}

validarIP_CalculadoraSubRedes() {
    echo -e "${AMARILLO}Introduce la IP con máscara (ej: 192.168.1.10/24): ${SC}"
    read -r ipmask

    # 1) Validar formato de IP/máscara
    if ! validar_ip_mascara "$ipmask"; then
        return
    fi

    echo -e "${AZUL}Calculando subred para ${ipmask}… 📊${SC}"

    # 2) Si ipcalc está disponible, usarlo
    if command -v ipcalc &> /dev/null; then
        ipcalc "$ipmask"
        return
    fi

    # 3) Cálculo manual
    ip="${ipmask%/*}"
    mask="${ipmask#*/}"

    # Obtener octetos
    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"

    # Convertir IP a entero 32-bits
    (( ipnum = (o1 << 24) | (o2 << 16) | (o3 << 8) | o4 ))

    # Construir máscara de 32 bits: n bits a 1 y el resto a 0
    (( masknum = (0xFFFFFFFF << (32 - mask)) & 0xFFFFFFFF ))

    # Dirección de red y broadcast
    (( netnum    = ipnum & masknum ))
    # Para el broadcast usamos la inversa de masknum, pero forzando 32 bits 
    (( bcastnum  = netnum | ((~masknum) & 0xFFFFFFFF) ))

    # Función auxiliar para pasar de 32-bits a dotted
    to_dotted() {
        local num=$1
        printf "%d.%d.%d.%d" $(( (num>>24)&0xFF )) \
                              $(( (num>>16)&0xFF )) \
                              $(( (num>>8)&0xFF ))  \
                              $(( num&0xFF ))
    }

    red="$(to_dotted "$netnum")/$mask"
    bcast="$(to_dotted "$bcastnum")"

    printf "Red:       %s\n" "$red"
    printf "Broadcast: %s\n" "$bcast"

    # 4) Rango de hosts y total
    if (( mask < 31 )); then
        (( first = netnum + 1 ))
        (( last  = bcastnum - 1 ))
        host_first="$(to_dotted "$first")"
        host_last="$(to_dotted "$last")"
        (( total = (1 << (32 - mask)) - 2 ))

        printf "Hosts válidos: %s – %s\n" "$host_first" "$host_last"
        echo -e "Número de hosts: ${VERDE}${total}${SC}"
    else
        echo -e "${NARANJA}No hay hosts asignables para máscara /$mask.${SC}"
    fi
}




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
        echo -e "${VERDE}Listando interfaces disponibles...${SC}"
        listar_interfaces
        pulsaFin
        ;;
    2)
        echo -e "${VERDE}Encender o apagar una interfaz...${SC}"
        listar_interfaces

        encenderapagar_interfaz
        pulsaFin
        ;;
    3)
        echo -e "${VERDE}Añadir una nueva interfaz de red...${SC}"
        anadir_interfaz
        pulsaFin
        ;;
    4)
        echo -e "${VERDE}Modificar una interfaz existente...${SC}"
        listar_interfaces
        modificar_interfaz
        pulsaFin
        ;;
    5)
        echo -e "${VERDE}Eliminar una interfaz de red...${SC}"
        listar_interfaces
        eliminar_interfaz
        pulsaFin
        ;;
    6)
        echo -e "${VERDE}Probar conectividad (Ping)...${SC}"
        listar_interfaces
        probar_ping
        pulsaFin 
        ;;
    7)
        echo -e "${VERDE}Monitorear actividad de una interfaz...${SC}"
        listar_interfaces
        monitorear_interfaz
        pulsaFin
        ;;
    8)
        echo -e "${VERDE}Diagnosticar problemas de red en una interfaz...${SC}"
        listar_interfaces
        diagnosticar_problemas_interfaz
        pulsaFin
        ;;
    9)
        echo -e "${VERDE}Validar IPs y calcular subredes...${SC}"
        validarIP_CalculadoraSubRedes
        pulsaFin
        ;;
    10)
        echo -e "${VERDE}Saliendo del menú de red...${SC}"
        sleep 1
        exit 0
        ;;
    
    esac
done
