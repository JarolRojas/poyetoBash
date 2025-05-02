#!/bin/bash
# Script de gestión de seguridad con Zenity y registro de acciones

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    zenity --error --text="Este script debe ejecutarse con sudo"
    exit 1
fi

# Verificar si Zenity está instalado
command -v zenity >/dev/null 2>&1 || { echo "Error: Zenity no está instalado. Instálalo con: sudo apt install zenity"; exit 1; }

# Directorio de backups y archivo de log
DESTINO="/copias_de_seguridad"
LOG_FILE="/var/log/seguridad_script.log"

# Crear archivo de log si no existe
touch "$LOG_FILE" || { zenity --error --text="No se pudo crear el archivo de log '$LOG_FILE'. Verifica permisos."; exit 1; }
chmod 600 "$LOG_FILE"

# Función para registrar acciones en el log
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

validar_backup() {
    if [ ! -d "$DESTINO" ]; then
        mkdir -p "$DESTINO" || { zenity --error --text="No se pudo crear el directorio '$DESTINO'. Verifica permisos."; exit 1; }
        chmod 700 "$DESTINO"
        log_action "Creado directorio de backups: $DESTINO"
    fi
    if [ ! -w "$DESTINO" ]; then
        zenity --error --text="No se puede escribir en '$DESTINO'. Verifica permisos."
        exit 1
    fi
}

realizar_backup() {
    validar_backup
    # Permitir selección de archivos o carpetas
    ORIGEN=$(zenity --file-selection --title="Selecciona archivo o carpeta a respaldar" --filename="$HOME/" --file-filter="All Files | *.*" --directory)
    [ -z "$ORIGEN" ] && { zenity --info --text="Operación cancelada: No se seleccionó ningún archivo o carpeta"; return 1; }
    [ ! -e "$ORIGEN" ] && { zenity --error --text="'$ORIGEN' no existe"; return 1; }
    
    # Mostrar contenido del elemento seleccionado
    if [ -d "$ORIGEN" ]; then
        mapfile -t CONTENIDO < <(ls -1 "$ORIGEN" 2>/dev/null)
        if [ ${#CONTENIDO[@]} -eq 0 ]; then
            zenity --warning --text="La carpeta '$ORIGEN' está vacía"
        else
            LISTA=()
            for item in "${CONTENIDO[@]}"; do
                LISTA+=("$item")
            done
            zenity --list --title="Contenido de $ORIGEN" --column="Archivos/Carpetas" "${LISTA[@]}" --width=600 --height=400
        fi
    else
        zenity --info --text="Seleccionaste el archivo: $(basename "$ORIGEN")"
    fi
    
    # Confirmar respaldo
    zenity --question --text="¿Confirmas respaldar '$ORIGEN'?" || { zenity --info --text="Operación cancelada"; return 1; }
    
    # Crear backup
    ARCHIVO="$DESTINO/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    if ! tar -czf "$ARCHIVO" -C "$(dirname "$ORIGEN")" "$(basename "$ORIGEN")" 2>/dev/null; then
        zenity --error --text="Fallo al crear la copia en '$ARCHIVO'"
        [ -f "$ARCHIVO" ] && rm -f "$ARCHIVO"
        log_action "Error al crear backup: $ARCHIVO"
        return 1
    fi
    zenity --info --text="Copia creada en: $ARCHIVO"
    log_action "Backup creado: $ARCHIVO"
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
    ARCHIVO=$(zenity --list --title="Eliminar Copia de Seguridad" --column="Copias disponibles" "${NOMBRES[@]}" --width=600 --height=400)
    [ -z "$ARCHIVO" ] && { zenity --error --text="No se seleccionó ninguna copia"; return 1; }
    
    ARCHIVO_COMPLETO="$DESTINO/$ARCHIVO"
    zenity --question --text="¿Confirmas eliminar '$ARCHIVO'?" || { zenity --info --text="Operación cancelada"; return 1; }
    if ! rm -f "$ARCHIVO_COMPLETO"; then
        zenity --error --text="No se pudo eliminar '$ARCHIVO_COMPLETO'. Verifica permisos."
        log_action "Error al eliminar backup: $ARCHIVO_COMPLETO"
        return 1
    fi
    zenity --info --text="Copia eliminada: $ARCHIVO"
    log_action "Backup eliminado: $ARCHIVO"
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
        zenity --list --title="Copias de Seguridad Disponibles" --column="Archivos" "${NOMBRES[@]}" --width=600 --height=400
    fi
    log_action "Listadas copias de seguridad"
}

enviar_informe_seguridad() {
    archivo_para_enviar="$LOG_FILE"
    if [[ -n "$archivo_para_enviar" ]]; then
        destinatario=$(zenity --entry --title="Correo Electrónico" --text="Ingresa el correo del destinatario:")
        if [[ -n "$destinatario" ]]; then
            zenity --info --text="Enviando $archivo_para_enviar a $destinatario..."
            python3 sendMail.py "$archivo_para_enviar" "$destinatario"
            if [[ $? -eq 0 ]]; then
                zenity --info --text="El correo fue enviado correctamente a $destinatario"
            else
                zenity --error --text="Ocurrió un error al enviar el correo."
            fi
        else
            zenity --error --text="No se ingresó un correo."
        fi
    else
        zenity --error --text="No hay archivo de log para enviar."
    fi
}

monitor_discos() {
    if ! df -h | zenity --text-info --title="Estado de Discos" --width=600 --height=400; then
        zenity --error --text="No se pudo mostrar el estado de los discos"
        log_action "Error al mostrar estado de discos"
        return 1
    fi
    log_action "Mostrado estado de discos"
}

administrar_particiones() {
    if ! fdisk -l 2>/dev/null | zenity --text-info --title="Administración de Particiones" --width=600 --height=400; then
        zenity --error --text="No se pudo listar las particiones. Verifica permisos o dispositivos."
        log_action "Error al listar particiones"
        return 1
    fi
    log_action "Listadas particiones"
}

limpiar_temporales() {
    if ! rm -rf /tmp/* /var/tmp/* 2>/dev/null; then
        zenity --error --text="No se pudieron eliminar archivos temporales. Verifica permisos."
        log_action "Error al limpiar archivos temporales"
        return 1
    fi
    zenity --info --text="Archivos temporales eliminados"
    log_action "Archivos temporales eliminados"
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
            log_action "Firewall habilitado"
            ;;
        "Deshabilitar UFW")
            ufw disable && zenity --info --text="Firewall deshabilitado" || zenity --error --text="Error al deshabilitar UFW"
            log_action "Firewall deshabilitado"
            ;;
        "Estado de UFW")
            ufw status | zenity --text-info --title="Estado del Firewall" || zenity --error --text="Error al mostrar estado"
            log_action "Mostrado estado de UFW"
            ;;
        "Añadir regla")
            PUERTO=$(zenity --entry --title="Añadir Regla" --text="Ingrese puerto (ej. 22):")
            PROTOCOLO=$(zenity --list --title="Protocolo" --column="Opción" "tcp" "udp")
            [[ -z "$PUERTO" || -z "$PROTOCOLO" ]] && { zenity --error --text="Puerto o protocolo vacío"; return 1; }
            ufw allow "$PUERTO/$PROTOCOLO" && zenity --info --text="Regla añadida: $PUERTO/$PROTOCOLO" || zenity --error --text="Error al añadir regla"
            log_action "Regla añadida: $PUERTO/$PROTOCOLO"
            ;;
        "Eliminar regla")
            NUMERO=$(ufw status numbered | zenity --text-info --title="Selecciona regla (ingresa número)" --editable)
            [[ -z "$NUMERO" ]] && { zenity --error --text="Número vacío"; return 1; }
            ufw delete "$NUMERO" && zenity --info --text="Regla eliminada" || zenity --error --text="Error al eliminar regla"
            log_action "Regla eliminada: $NUMERO"
            ;;
        *) zenity --error --text="Opción cancelada";;
    esac
}

analizar_vulnerabilidades() {
    if ! command -v lynis >/dev/null 2>&1; then
        zenity --error --text="Lynis no está instalado. Instálalo con: sudo apt install lynis"
        return 1
    fi
    if ! lynis audit system > /tmp/lynis_report.txt 2>/dev/null; then
        zenity --error --text="Fallo al ejecutar Lynis"
        log_action "Error al ejecutar Lynis"
        return 1
    fi
    zenity --text-info --title="Análisis de Seguridad" --filename=/tmp/lynis_report.txt --width=700 --height=500
    log_action "Análisis de vulnerabilidades ejecutado"
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