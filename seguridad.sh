#!/bin/bash
# Script de gestión de seguridad con Zenity mejorado

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    zenity --error --text="Este script debe ejecutarse con sudo"
    exit 1
fi

# Verificar si Zenity está instalado
command -v zenity >/dev/null 2>&1 || { echo "Error: Zenity no está instalado. Instálalo con: sudo apt install zenity"; exit 1; }

# Directorio de backups
DESTINO="/copias_de_seguridad"

validar_backup() {
    if [ ! -d "$DESTINO" ]; then
        mkdir -p "$DESTINO" || { zenity --error --text="No se pudo crear el directorio '$DESTINO'. Verifica permisos."; exit 1; }
        chmod 700 "$DESTINO"
    fi
    if [ ! -w "$DESTINO" ]; then
        zenity --error --text="No se puede escribir en '$DESTINO'. Verifica permisos."
        exit 1
    fi
}

realizar_backup() {
    validar_backup
    ORIGEN=$(zenity --file-selection --title="Selecciona archivo o carpeta a respaldar" --filename="$HOME/")
    [ -z "$ORIGEN" ] && { zenity --error --text="No se seleccionó ningún archivo o carpeta"; return 1; }
    [ ! -e "$ORIGEN" ] && { zenity --error --text="'$ORIGEN' no existe"; return 1; }
    
    ARCHIVO="$DESTINO/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    if ! tar -czf "$ARCHIVO" "$ORIGEN" 2>/dev/null; then
        zenity --error --text="Fallo al crear la copia en '$ARCHIVO'"
        [ -f "$ARCHIVO" ] && rm -f "$ARCHIVO"
        return 1
    fi
    zenity --info --text="Copia creada en: $ARCHIVO"
}

eliminar_backup() {
    validar_backup
    mapfile -t ARCHIVOS < <(ls -1 "$DESTINO"/*.tar.gz 2>/dev/null)
    if [ ${#ARCHIVOS[@]} -eq 0 ]; then
        zenity --error --text="No hay copias de seguridad en '$DESTINO'"
        return 1
    fi
    
    NOMBRES=()
    for archivo in "${ARCHIVOS[@]}"; do
        NOMBRES+=("$(basename "$archivo")")
    done
    ARCHIVO=$(zenity --list --title="Selecciona copia a eliminar" --column="Copias" "${NOMBRES[@]}")
    [ -z "$ARCHIVO" ] && { zenity --error --text="No se seleccionó ninguna copia"; return 1; }
    
    ARCHIVO_COMPLETO="$DESTINO/$ARCHIVO"
    if ! rm -f "$ARCHIVO_COMPLETO"; then
        zenity --error --text="No se pudo eliminar '$ARCHIVO_COMPLETO'. Verifica permisos."
        return 1
    fi
    zenity --info --text="Copia eliminada: $ARCHIVO"
}

listar_backup() {
    validar_backup
    mapfile -t ARCHIVOS < <(ls -1 "$DESTINO"/*.tar.gz 2>/dev/null)
    if [ ${#ARCHIVOS[@]} -eq 0 ]; then
        zenity --info --text="No hay copias de seguridad en '$DESTINO'"
    else
        NOMBRES=()
        for archivo in "${ARCHIVOS[@]}"; do
            NOMBRES+=("$(basename "$archivo")")
        done
        zenity --list --title="Copias de Seguridad" --column="Archivos" "${NOMBRES[@]}"
    fi
}

enviar_informe_seguridad() {
    ARCHIVO=$(zenity --file-selection --title="Selecciona el backup a enviar" --filename="$DESTINO/" --file-filter="*.tar.gz")
    [ -z "$ARCHIVO" ] && { zenity --error --text="No se seleccionó ningún archivo"; return 1; }
    [ ! -f "$ARCHIVO" ] && { zenity --error --text="'$ARCHIVO' no existe"; return 1; }
    
    DESTINATARIO=$(zenity --entry --title="Correo Electrónico" --text="Ingresa el correo destinatario")
    [[ -z "$DESTINATARIO" ]] && { zenity --error --text="No se ingresó un destinatario"; return 1; }
    [[ ! "$DESTINATARIO" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && { zenity --error --text="Formato de correo inválido"; return 1; }
    
    if ! echo "Adjunto copia de seguridad" | mail -s "Backup" -A "$ARCHIVO" "$DESTINATARIO"; then
        zenity --error --text="Fallo al enviar el correo. Verifica mailutils o la configuración."
        return 1
    fi
    zenity --info --text="Copia enviada a $DESTINATARIO"
}

monitor_discos() {
    if ! df -h | zenity --text-info --title="Estado de Discos" --width=600 --height=400; then
        zenity --error --text="No se pudo mostrar el estado de los discos"
        return 1
    fi
}

administrar_particiones() {
    if ! fdisk -l 2>/dev/null | zenity --text-info --title="Administración de Particiones" --width=600 --height=400; then
        zenity --error --text="No se pudo listar las particiones. Verifica permisos o dispositivos."
        return 1
    fi
}

limpiar_temporales() {
    if ! rm -rf /tmp/* /var/tmp/* 2>/dev/null; then
        zenity --error --text="No se pudieron eliminar archivos temporales. Verifica permisos."
        return 1
    fi
    zenity --info --text="Archivos temporales eliminados"
}

configurar_firewall() {
    if ! command -v ufw >/dev/null 2>&1; then
        zenity --error --text="UFW no está instalado. Instálalo con: sudo apt install ufw"
        return 1
    fi
    
    OPCION=$(zenity --list --title="Configurar Firewall" --column="Acción" \
        "Habilitar UFW" "Deshabilitar UFW" "Estado de UFW" "Añadir regla" "Eliminar regla")
    case "$OPCION" in
        "Habilitar UFW") 
            ufw enable && zenity --info --text="Firewall habilitado" || zenity --error --text="Error al habilitar UFW"
            ;;
        "Deshabilitar UFW") 
            ufw disable && zenity --info --text="Firewall deshabilitado" || zenity --error --text="Error al deshabilitar UFW"
            ;;
        "Estado de UFW") 
            ufw status | zenity --text-info --title="Estado del Firewall" || zenity --error --text="Error al mostrar estado"
            ;;
        "Añadir regla")
            PUERTO=$(zenity --entry --title="Añadir Regla" --text="Ingrese puerto (ej. 22):")
            PROTOCOLO=$(zenity --list --title="Protocolo" --column="Opción" "tcp" "udp")
            [[ -z "$PUERTO" || -z "$PROTOCOLO" ]] && { zenity --error --text="Puerto o protocolo vacío"; return 1; }
            ufw allow "$PUERTO/$PROTOCOLO" && zenity --info --text="Regla añadida: $PUERTO/$PROTOCOLO" || zenity --error --text="Error al añadir regla"
            ;;
        "Eliminar regla")
            NUMERO=$(ufw status numbered | zenity --text-info --title="Selecciona regla (ingresa número)" --editable)
            [[ -z "$NUMERO" ]] && { zenity --error --text="Número vacío"; return 1; }
            ufw delete "$NUMERO" && zenity --info --text="Regla eliminada" || zenity --error --text="Error al eliminar regla"
            ;;
        *) 
            zenity --error --text="Opción cancelada";;
    esac
}

analizar_vulnerabilidades() {
    if ! command -v lynis >/dev/null 2>&1; then
        zenity --error --text="Lynis no está instalado. Instálalo con: sudo apt install lynis"
        return 1
    fi
    if ! lynis audit system > /tmp/lynis_report.txt 2>/dev/null; then
        zenity --error --text="Fallo al ejecutar Lynis"
        return 1
    fi
    zenity --text-info --title="Análisis de Seguridad" --filename=/tmp/lynis_report.txt --width=700 --height=500
}

# Menú principal
while true; do
    opcion=$(zenity --list --title="Gestión de Seguridad" \
        --column="Opción" --column="Acción" \
        1 "Copias de Seguridad" \
        2 "Gestión de Almacenamiento" \
        3 "Configurar Firewall" \
        4 "Análisis de Vulnerabilidades" \
        5 "Salir" --height=300)
    case "$opcion" in
        1)
            subopcion=$(zenity --list --title="Copias de Seguridad" \
                --column="Opción" --column="Acción" \
                1 "Realizar" 2 "Eliminar" 3 "Listar" 4 "Enviar por correo" --height=250)
            case "$subopcion" in
                1) realizar_backup;;
                2) eliminar_backup;;
                3) listar_backup;;
                4) enviar_informe_seguridad;;
            esac
            ;;
        2)
            subopcion=$(zenity --list --title="Gestión de Almacenamiento" \
                --column="Opción" --column="Acción" \
                1 "Monitor de Discos" 2 "Administración de Particiones" 3 "Limpieza de Temporales" --height=250)
            case "$subopcion" in
                1) monitor_discos;;
                2) administrar_particiones;;
                3) limpiar_temporales;;
            esac
            ;;
        3) configurar_firewall;;
        4) analizar_vulnerabilidades;;
        5) exit 0;;
        *) zenity --error --text="Opción inválida";;
    esac
done