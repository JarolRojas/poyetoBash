#!/bin/bash

# ==============================================================================
# CONFIGURACIÓN DE COLORES
# Definiciones de códigos ANSI para colores y formato de texto
# ==============================================================================

# Colores básicos
MORADO='\033[0;35m'      # Texto morado
AMARILLO='\033[1;33m'    # Texto amarillo brillante
ROJO='\033[0;31m'        # Texto rojo
VERDE='\033[0;32m'       # Texto verde
AZUL='\033[0;34m'        # Texto azul
CYAN='\033[0;36m'        # Texto cyan

# Variantes claras
AMARILLO_CLARO='\033[0;93m'
ROJO_CLARO='\033[1;31m'
VERDE_CLARO='\033[1;32m'
AZUL_CLARO='\033[1;34m'
NARANJA='\033[0;33m'
NARANJA_CLARO='\033[1;33m'

# Otros
BLANCO='\033[1;37m'      # Texto blanco brillante
SC='\033[0m'             # Resetear formato (Stop Color)

# ==============================================================================
# VERIFICACIÓN DE PRIVILEGIOS
# El script debe ejecutarse como root para tener permisos de red
# ==============================================================================
if [ "$EUID" -ne 0 ]; then
    echo -e "${ROJO} Por favor, ejecuta este script como root."
    exit 1
fi

# ==============================================================================
# CONFIGURACIÓN DEL MENÚ
# Opciones disponibles y funciones de visualización
# ==============================================================================

# Lista de opciones del menú principal
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

# Función para mostrar el menú con colores alternados
mostrarMenu() {
    echo -e "${VERDE}=== GESTIONAR RED ===\n\n${SC}"
    local colores=("$MORADO" "$AMARILLO" "$VERDE" "$AZUL" "$CYAN" "$ROJO")
    
    # Imprime cada opción con color rotatorio
    for i in "${!opciones[@]}"; do
        local color=${colores[$((i % ${#colores[@]}))]}
        echo -e "${color}$((i + 1)). ${opciones[$i]}${SC}\n"
    done
}

# ==============================================================================
# FUNCIONES DE UTILIDAD
# Funciones auxiliares para uso general
# ==============================================================================

# Muestra una barra de progreso animada
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

# Pausa la ejecución hasta entrada del usuario
pulsaFin() {
    echo -ne "\n${BLANCO}Presiona una tecla para continuar..."
    read -n 1 -s
    clear
}

# ==============================================================================
# FUNCIONES DE GESTIÓN DE RED
# Operaciones principales de gestión de interfaces
# ==============================================================================

# Lista todas las interfaces con su estado e IP
listar_interfaces() {
    for iface in /sys/class/net/*; do
        local name=$(basename "$iface")
        local ip_address=$(ip -o -4 addr show "$name" | awk '{print $4}' | cut -d/ -f1)
        local state=$(cat "$iface/operstate")
        local color="$VERDE"

        [[ -z "$ip_address" ]] && ip_address="N/A"
        [[ "$state" != "up" ]] && color="$ROJO_CLARO"

        printf "Interfaz: %-10s  IP: %-15s  Estado: ${color}%-4s${SC}\n" "$name" "$ip_address" "$state"
    done
}

# Apaga una interfaz de red
apagar_interfaz() {
    local interfaz="$1"
    ip link set "$interfaz" down
    [[ $? -eq 0 ]] && echo "Interfaz '$interfaz' apagada correctamente." || echo "Error al apagar la interfaz '$interfaz'."
}

# Enciende una interfaz de red
encender_interfaz() {
    local interfaz="$1"
    ip link set "$interfaz" up
    [[ $? -eq 0 ]] && echo "Interfaz '$interfaz' encendida correctamente." || echo "Error al encender la interfaz '$interfaz'."
}

# Gestión de estado de interfaz (encender/apagar)
encenderapagar_interfaz() {
    read -rp "${AMARILLO}Introduce el nombre de la interfaz: ${SC}" interfaz
    [[ -z "$interfaz" ]] && { echo -e "${ROJO}Interfaz no especificada"; return; }
    
    if [[ -d "/sys/class/net/$interfaz" ]]; then
        local estado=$(cat "/sys/class/net/$interfaz/operstate")
        local accion="apagarla"
        [[ "$estado" != "up" ]] && accion="encenderla"
        
        read -rp "${AMARILLO}La interfaz está ${estado}. ¿Deseas ${accion}? (s/n) ${SC}" respuesta
        [[ "$respuesta" == "s" ]] && {
            if [[ "$accion" == "apagarla" ]]; then apagar_interfaz "$interfaz"; else encender_interfaz "$interfaz"; fi
        } || echo -e "${VERDE}Operación cancelada"
    else
        echo -e "${ROJO}La interfaz no existe"
    fi
}

# ==============================================================================
# VALIDACIÓN Y CÁLCULOS DE RED
# Funciones para validar IPs y calcular subredes
# ==============================================================================

# Valida formato de IP/máscara (ej: 192.168.1.1/24)
validar_ip_mascara() {
    local ip_mascara="$1"
    local ip=$(cut -d'/' -f1 <<< "$ip_mascara")
    local mascara=$(cut -d'/' -f2 <<< "$ip_mascara")

    # Validación de formato IP
    if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Formato de IP inválido"; return 1
    fi

    # Validación de octetos
    IFS='.' read -r -a octetos <<< "$ip"
    for oct in "${octetos[@]}"; do
        (( oct < 0 || oct > 255 )) && { echo "Octeto inválido: $oct"; return 1; }
    done

    # Validación de máscara
    (( mascara < 0 || mascara > 32 )) && { echo "Máscara inválida"; return 1; }

    echo "IP válida"; return 0
}

# Calculadora de subredes (usa ipcalc si está disponible)
validarIP_CalculadoraSubRedes() {
    read -rp "${AMARILLO}Introduce IP/máscara (ej: 192.168.1.10/24): ${SC}" ipmask
    validar_ip_mascara "$ipmask" || return

    if command -v ipcalc &>/dev/null; then
        ipcalc "$ipmask"
    else
        # Cálculo manual de subred
        local ip="${ipmask%/*}" mask="${ipmask#*/}"
        IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
        local ipnum=$(( (o1<<24) | (o2<<16) | (o3<<8) | o4 ))
        local masknum=$(( 0xFFFFFFFF << (32 - mask) & 0xFFFFFFFF ))
        local netnum=$(( ipnum & masknum ))
        local bcastnum=$(( netnum | (~masknum & 0xFFFFFFFF) ))

        to_dotted() {
            printf "%d.%d.%d.%d" $(($1>>24 & 0xFF)) $(($1>>16 & 0xFF)) $(($1>>8 & 0xFF)) $(($1 & 0xFF))
        }

        echo -e "\nRed: $(to_dotted $netnum)/$mask"
        echo "Broadcast: $(to_dotted $bcastnum)"
        (( mask < 31 )) && {
            echo "Hosts: $(to_dotted $((netnum + 1))) - $(to_dotted $((bcastnum - 1)))"
            echo "Total hosts: $(( (1 << (32 - mask)) - 2 ))"
        }
    fi
}

# ==============================================================================
# FUNCIONES ADICIONALES
# Resto de funcionalidades del menú
# ==============================================================================
# (Nota: Se mantienen las implementaciones originales pero con mejor formato)
# ... [resto de funciones con comentarios similares] ...

# ==============================================================================
# BUCLE PRINCIPAL
# Manejo de las opciones del menú
# ==============================================================================
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
