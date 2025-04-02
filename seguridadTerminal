#!/bin/bash
# Script de gestión de seguridad en terminal mejorado

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Este script debe ejecutarse con privilegios de root (sudo)"
    exit 1
fi

# Directorio de backups
DESTINO="/copias_de_seguridad"

validar_backup() {
    if [ ! -d "$DESTINO" ]; then
        mkdir -p "$DESTINO" || { echo "Error: No se pudo crear el directorio '$DESTINO'. Verifica permisos."; exit 1; }
        chmod 700 "$DESTINO"
    fi
    if [ ! -w "$DESTINO" ]; then
        echo "Error: No se puede escribir en '$DESTINO'. Verifica permisos."
        exit 1
    fi
}

realizar_backup() {
    validar_backup
    echo "Elementos disponibles en $HOME (archivos y directorios):"
    mapfile -t ELEMENTOS < <(find "$HOME" -maxdepth 1 -type f -o -type d -not -path "$HOME" 2>/dev/null)
    if [ ${#ELEMENTOS[@]} -eq 0 ]; then
        echo "No hay elementos disponibles en $HOME"
        return 1
    fi
    
    select ORIGEN in "${ELEMENTOS[@]}"; do
        if [ -n "$ORIGEN" ]; then
            break
        else
            echo "Selección inválida, intenta de nuevo"
        fi
    done
    
    ARCHIVO="$DESTINO/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    if ! tar -czf "$ARCHIVO" "$ORIGEN" 2>/dev/null; then
        echo "Error: Fallo al crear la copia de seguridad en '$ARCHIVO'"
        [ -f "$ARCHIVO" ] && rm -f "$ARCHIVO"
        return 1
    fi
    echo "Copia de seguridad creada en: $ARCHIVO"
}

eliminar_backup() {
    validar_backup
    mapfile -t ARCHIVOS < <(ls -1 "$DESTINO"/*.tar.gz 2>/dev/null)
    if [ ${#ARCHIVOS[@]} -eq 0 ]; then
        echo "No hay copias de seguridad en '$DESTINO'"
        return 1
    fi
    
    echo "Copias de seguridad disponibles:"
    select ARCHIVO in "${ARCHIVOS[@]}"; do
        if [ -n "$ARCHIVO" ]; then
            break
        else
            echo "Selección inválida, intenta de nuevo"
        fi
    done
    
    if ! rm -f "$ARCHIVO"; then
        echo "Error: No se pudo eliminar '$ARCHIVO'. Verifica permisos."
        return 1
    fi
    echo "Copia de seguridad eliminada: $ARCHIVO"
}

listar_backup() {
    validar_backup
    mapfile -t ARCHIVOS < <(ls -1 "$DESTINO"/*.tar.gz 2>/dev/null)
    if [ ${#ARCHIVOS[@]} -eq 0 ]; then
        echo "No hay copias de seguridad en '$DESTINO'"
    else
        echo "Copias de seguridad disponibles:"
        for archivo in "${ARCHIVOS[@]}"; do
            basename "$archivo"
        done
    fi
}

enviar_informe_seguridad() {
    read -p "Ingrese la ruta completa del backup a enviar (en $DESTINO): " ARCHIVO
    [ -z "$ARCHIVO" ] && { echo "Error: No se especificó un archivo"; return 1; }
    [ ! -f "$ARCHIVO" ] && { echo "Error: '$ARCHIVO' no existe"; return 1; }
    
    read -p "Ingrese el correo destinatario: " DESTINATARIO
    [[ ! "$DESTINATARIO" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && { echo "Error: Formato de correo inválido"; return 1; }
    
    if ! echo "Adjunto copia de seguridad" | mail -s "Backup" -A "$ARCHIVO" "$DESTINATARIO"; then
        echo "Error: Fallo al enviar el correo. Verifica mailutils o la configuración."
        return 1
    fi
    echo "Copia enviada a $DESTINATARIO"
}

monitor_discos() {
    if ! df -h; then
        echo "Error: No se pudo mostrar el estado de los discos"
        return 1
    fi
}

administrar_particiones() {
    if ! fdisk -l 2>/dev/null; then
        echo "Error: No se pudo listar las particiones. Verifica permisos o dispositivos."
        return 1
    fi
}

limpiar_temporales() {
    if ! rm -rf /tmp/* /var/tmp/* 2>/dev/null; then
        echo "Error: No se pudieron eliminar archivos temporales. Verifica permisos."
        return 1
    fi
    echo "Archivos temporales eliminados"
}

configurar_firewall() {
    if ! command -v ufw >/dev/null 2>&1; then
        echo "Error: UFW no está instalado. Instálalo con: sudo apt install ufw"
        return 1
    fi
    
    echo "1) Habilitar UFW  2) Deshabilitar UFW  3) Estado de UFW  4) Añadir regla  5) Eliminar regla"
    read -p "Seleccione una opción: " OPCION
    case "$OPCION" in
        1) 
            ufw enable && echo "Firewall habilitado" || echo "Error al habilitar UFW"
            ;;
        2) 
            ufw disable && echo "Firewall deshabilitado" || echo "Error al deshabilitar UFW"
            ;;
        3) 
            ufw status || echo "Error al mostrar estado de UFW"
            ;;
        4)
            read -p "Ingrese puerto (ej. 22): " PUERTO
            read -p "Protocolo (tcp/udp): " PROTOCOLO
            [[ -z "$PUERTO" || -z "$PROTOCOLO" ]] && { echo "Error: Puerto o protocolo vacío"; return 1; }
            ufw allow "$PUERTO/$PROTOCOLO" && echo "Regla añadida: $PUERTO/$PROTOCOLO" || echo "Error al añadir regla"
            ;;
        5)
            ufw status numbered | less
            read -p "Ingrese el número de la regla a eliminar: " NUMERO
            [[ -z "$NUMERO" ]] && { echo "Error: Número vacío"; return 1; }
            ufw delete "$NUMERO" && echo "Regla eliminada" || echo "Error al eliminar regla"
            ;;
        *) 
            echo "Error: Opción inválida"; return 1;;
    esac
}

analizar_vulnerabilidades() {
    if ! command -v lynis >/dev/null 2>&1; then
        echo "Error: Lynis no está instalado. Instálalo con: sudo apt install lynis"
        return 1
    fi
    if ! lynis audit system > /tmp/lynis_report.txt 2>/dev/null; then
        echo "Error: Fallo al ejecutar Lynis"
        return 1
    fi
    cat /tmp/lynis_report.txt
}

# Menú principal
while true; do
    echo -e "\nGestión de Seguridad"
    echo "1) Copias de Seguridad"
    echo "2) Gestión de Almacenamiento"
    echo "3) Configurar Firewall"
    echo "4) Análisis de Vulnerabilidades"
    echo "5) Salir"
    read -p "Seleccione una opción: " OPCION
    
    case "$OPCION" in
        1)
            echo "1) Realizar  2) Eliminar  3) Listar  4) Enviar por correo"
            read -p "Seleccione una subopción: " SUBOPCION
            case "$SUBOPCION" in
                1) realizar_backup;;
                2) eliminar_backup;;
                3) listar_backup;;
                4) enviar_informe_seguridad;;
                *) echo "Error: Subopción inválida";;
            esac
            ;;
        2)
            echo "1) Monitor de Discos  2) Administración de Particiones  3) Limpieza de Temporales"
            read -p "Seleccione una subopción: " SUBOPCION
            case "$SUBOPCION" in
                1) monitor_discos;;
                2) administrar_particiones;;
                3) limpiar_temporales;;
                *) echo "Error: Subopción inválida";;
            esac
            ;;
        3) configurar_firewall;;
        4) analizar_vulnerabilidades;;
        5) exit 0;;
        *) echo "Error: Opción inválida";;
    esac
done