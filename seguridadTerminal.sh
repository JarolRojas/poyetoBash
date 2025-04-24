#!/bin/bash
# Script de gestión de seguridad en terminal con registro de acciones

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Este script debe ejecutarse con sudo"
    exit 1
fi

# Directorio de backups y archivo de log
DESTINO="/copias_de_seguridad"
LOG_FILE="/var/log/seguridad_script.log"

# Crear archivo de log si no existe
touch "$LOG_FILE" || { echo "Error: No se pudo crear el archivo de log '$LOG_FILE'. Verifica permisos."; exit 1; }
chmod 600 "$LOG_FILE"

# Función para registrar acciones en el log
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

validar_backup() {
    if [ ! -d "$DESTINO" ]; then
        mkdir -p "$DESTINO" || { echo "Error: No se pudo crear el directorio '$DESTINO'. Verifica permisos."; exit 1; }
        chmod 700 "$DESTINO"
        log_action "Creado directorio de backups: $DESTINO"
    fi
    if [ ! -w "$DESTINO" ]; then
        echo "Error: No se puede escribir en '$DESTINO'. Verifica permisos."
        exit 1
    fi
}

realizar_backup() {
    validar_backup
    echo "Archivos y carpetas disponibles en $HOME:"
    mapfile -t ITEMS < <(ls -1 "$HOME" 2>/dev/null)
    if [ ${#ITEMS[@]} -eq 0 ]; then
        echo "Error: No hay archivos o carpetas en '$HOME'"
        return 1
    fi
    
    echo "Selecciona un archivo o carpeta para respaldar:"
    PS3="Ingresa el número: "
    select ITEM in "${ITEMS[@]}" "Cancelar"; do
        if [[ "$ITEM" == "Cancelar" ]]; then
            echo "Operación cancelada"
            return 1
        fi
        [ -z "$ITEM" ] && { echo "Error: Selección inválida"; continue; }
        ORIGEN="$HOME/$ITEM"
        [ ! -e "$ORIGEN" ] && { echo "Error: '$ORIGEN' no existe"; continue; }
        break
    done
    
    # Mostrar contenido del elemento seleccionado
    echo "Contenido en '$ORIGEN':"
    ls -l "$ORIGEN" 2>/dev/null || echo "No se puede listar (puede ser un archivo)"
    echo "Confirma que deseas respaldar '$ORIGEN' (s/n):"
    read -r CONFIRMAR
    [[ "$CONFIRMAR" != "s" && "$CONFIRMAR" != "S" ]] && { echo "Operación cancelada"; return 1; }
    
    ARCHIVO="$DESTINO/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    if ! tar -czf "$ARCHIVO" "$ORIGEN" 2>/dev/null; then
        echo "Error: Fallo al crear la copia en '$ARCHIVO'"
        [ -f "$ARCHIVO" ] && rm -f "$ARCHIVO"
        log_action "Error al crear backup: $ARCHIVO"
        return 1
    fi
    echo "Copia creada en: $ARCHIVO"
    log_action "Backup creado: $ARCHIVO"
}

eliminar_backup() {
    validar_backup
    mapfile -t ARCHIVOS < <(ls -1 "$DESTINO"/*.tar.gz 2>/dev/null)
    if [ ${#ARCHIVOS[@]} -eq 0 ]; then
        echo "Error: No hay copias de seguridad en '$DESTINO'"
        return 1
    fi
    
    echo "Copias de seguridad disponibles en '$DESTINO':"
    PS3="Selecciona la copia a eliminar (número): "
    select ARCHIVO in "${ARCHIVOS[@]##*/}" "Cancelar"; do
        if [[ "$ARCHIVO" == "Cancelar" ]]; then
            echo "Operación cancelada"
            return 1
        fi
        [ -z "$ARCHIVO" ] && { echo "Error: Selección inválida"; continue; }
        ARCHIVO_COMPLETO="$DESTINO/$ARCHIVO"
        if ! rm -f "$ARCHIVO_COMPLETO"; then
            echo "Error: No se pudo eliminar '$ARCHIVO_COMPLETO'. Verifica permisos."
            log_action "Error al eliminar backup: $ARCHIVO_COMPLETO"
            return 1
        fi
        echo "Copia eliminada: $ARCHIVO"
        log_action "Backup eliminado: $ARCHIVO"
        break
    done
}

listar_backup() {
    validar_backup
    mapfile -t ARCHIVOS < <(ls -1 "$DESTINO"/*.tar.gz 2>/dev/null)
    if [ ${#ARCHIVOS[@]} -eq 0 ]; then
        echo "No hay copias de seguridad en '$DESTINO'"
    else
        echo "Copias de seguridad:"
        for archivo in "${ARCHIVOS[@]}"; do
            echo "- $(basename "$archivo")"
        done
    fi
    log_action "Listadas copias de seguridad"
}

enviar_informe_seguridad() {
    archivo_para_enviar="$LOG_FILE"
    if [[ -n "$archivo_para_enviar" ]]; then
        read -p "Ingresa el correo del destinatario: " destinatario
        if [[ -n "$destinatario" ]]; then
            echo "Enviando $archivo_para_enviar a $destinatario..."
            python3 sendMail.py "$archivo_para_enviar" "$destinatario"
            if [[ $? -eq 0 ]]; then
                echo "El correo fue enviado correctamente a $destinatario"
            else
                echo "Ocurrió un error al enviar el correo."
            fi
        else
            echo "No se ingresó un correo."
        fi
    else
        echo "No hay archivo de log para enviar."
    fi
}

monitor_discos() {
    if ! df -h; then
        echo "Error: No se pudo mostrar el estado de los discos"
        log_action "Error al mostrar estado de discos"
        return 1
    fi
    log_action "Mostrado estado de discos"
}

administrar_particiones() {
    if ! fdisk -l 2>/dev/null; then
        echo "Error: No se pudo listar las particiones. Verifica permisos o dispositivos."
        log_action "Error al listar particiones"
        return 1
    fi
    log_action "Listadas particiones"
}

limpiar_temporales() {
    if ! rm -rf /tmp/* /var/tmp/* 2>/dev/null; then
        echo "Error: No se pudieron eliminar archivos temporales. Verifica permisos."
        log_action "Error al limpiar archivos temporales"
        return 1
    fi
    echo "Archivos temporales eliminados"
    log_action "Archivos temporales eliminados"
}

configurar_firewall() {
    if ! command -v ufw >/dev/null 2>&1; then
        echo "Error: UFW no está instalado. Instálalo con: sudo apt install ufw"
        return 1
    fi
    
    echo "Configurar Firewall:"
    PS3="Selecciona una opción: "
    options=("Habilitar UFW" "Deshabilitar UFW" "Estado de UFW" "Añadir regla" "Eliminar regla" "Cancelar")
    select OPCION in "${options[@]}"; do
        case "$OPCION" in
            "Habilitar UFW")
                ufw enable && echo "Firewall habilitado" || echo "Error al habilitar UFW"
                log_action "Firewall habilitado"
                break
                ;;
            "Deshabilitar UFW")
                ufw disable && echo "Firewall deshabilitado" || echo "Error al deshabilitar UFW"
                log_action "Firewall deshabilitado"
                break
                ;;
            "Estado de UFW")
                ufw status || echo "Error al mostrar estado"
                log_action "Mostrado estado de UFW"
                break
                ;;
            "Añadir regla")
                echo "Ingrese puerto (ej. 22):"
                read -r PUERTO
                echo "Selecciona protocolo (tcp/udp):"
                read -r PROTOCOLO
                [[ -z "$PUERTO" || -z "$PROTOCOLO" ]] && { echo "Error: Puerto o protocolo vacío"; return 1; }
                ufw allow "$PUERTO/$PROTOCOLO" && echo "Regla añadida: $PUERTO/$PROTOCOLO" || echo "Error al añadir regla"
                log_action "Regla añadida: $PUERTO/$PROTOCOLO"
                break
                ;;
            "Eliminar regla")
                ufw status numbered
                echo "Ingrese el número de la regla a eliminar:"
                read -r NUMERO
                [[ -z "$NUMERO" ]] && { echo "Error: Número vacío"; return 1; }
                ufw delete "$NUMERO" && echo "Regla eliminada" || echo "Error al eliminar regla"
                log_action "Regla eliminada: $NUMERO"
                break
                ;;
            "Cancelar")
                echo "Operación cancelada"
                break
                ;;
            *) echo "Opción inválida";;
        esac
    done
}

analizar_vulnerabilidades() {
    if ! command -v lynis >/dev/null 2>&1; then
        echo "Error: Lynis no está instalado. Instálalo con: sudo apt install lynis"
        return 1
    fi
    if ! lynis audit system > /tmp/lynis_report.txt 2>/dev/null; then
        echo "Error: Fallo al ejecutar Lynis"
        log_action "Error al ejecutar Lynis"
        return 1
    fi
    cat /tmp/lynis_report.txt
    log_action "Análisis de vulnerabilidades ejecutado"
}

# Menú principal
while true; do
    echo -e "\n=== Gestión de Seguridad ==="
    PS3="Selecciona una opción: "
    options=("Copias de Seguridad" "Gestión de Almacenamiento" "Configurar Firewall" "Análisis de Vulnerabilidades" "Salir")
    select opcion in "${options[@]}"; do
        case "$opcion" in
            "Copias de Seguridad")
                echo -e "\n=== Copias de Seguridad ==="
                PS3="Selecciona una acción: "
                suboptions=("Realizar" "Eliminar" "Listar" "Enviar por correo")
                select subopcion in "${suboptions[@]}"; do
                    case "$subopcion" in
                        "Realizar") realizar_backup;;
                        "Eliminar") eliminar_backup;;
                        "Listar") listar_backup;;
                        "Enviar por correo") enviar_informe_seguridad;;
                        *) echo "Opción inválida";;
                    esac
                    break
                done
                break
                ;;
            "Gestión de Almacenamiento")
                echo -e "\n=== Gestión de Almacenamiento ==="
                PS3="Selecciona una acción: "
                suboptions=("Monitor de Discos" "Administración de Particiones" "Limpieza de Temporales")
                select subopcion in "${suboptions[@]}"; do
                    case "$subopcion" in
                        "Monitor de Discos") monitor_discos;;
                        "Administración de Particiones") administrar_particiones;;
                        "Limpieza de Temporales") limpiar_temporales;;
                        *) echo "Opción inválida";;
                    esac
                    break
                done
                break
                ;;
            "Configurar Firewall") configurar_firewall;;
            "Análisis de Vulnerabilidades") analizar_vulnerabilidades;;
            "Salir") exit 0;;
            *) echo "Opción inválida";;
        esac
        break
    done
done