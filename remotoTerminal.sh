#!/bin/bash
# Script para controlar el acceso remoto a SSH en Ubuntu (versión terminal)

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

# Archivo de log
LOG_FILE="/var/log/ssh_management.log"

# Crear archivo de log si no existe
touch "$LOG_FILE" || { echo "Error: No se pudo crear el archivo de log '$LOG_FILE'. Verifica permisos."; exit 1; }
chmod 600 "$LOG_FILE"

# Función para registrar acciones en el log
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Verificar e instalar openssh-server
verificar_ssh() {
    if ! dpkg -l | grep -q openssh-server; then
        echo "El paquete openssh-server no está instalado."
        echo "¿Deseas instalarlo ahora? (s/n)"
        read -r RESPUESTA
        if [[ "$RESPUESTA" == "s" || "$RESPUESTA" == "S" ]]; then
            apt update
            apt install -y openssh-server || { echo "Error: No se pudo instalar openssh-server."; exit 1; }
            log_action "Instalado openssh-server"
        else
            echo "No se puede continuar sin openssh-server. Saliendo."
            exit 1
        fi
    fi
}

# Determinar el nombre del servicio (ssh o sshd)
determinar_servicio() {
    if systemctl list-units --full -all | grep -q "ssh.service"; then
        SERVICIO="ssh"
    elif systemctl list-units --full -all | grep -q "sshd.service"; then
        SERVICIO="sshd"
    else
        echo "Error: No se encontró el servicio SSH (ni ssh ni sshd). Verifica la instalación."
        log_action "Error: Servicio SSH no encontrado"
        exit 1
    fi
}

# Configurar AllowGroups en sshd_config
configurar_ssh() {
    if ! grep -q "AllowGroups sshusers" /etc/ssh/sshd_config; then
        echo "AllowGroups sshusers" >> /etc/ssh/sshd_config
        groupadd -f sshusers
        systemctl restart "$SERVICIO" 2>/dev/null || { echo "Error al reiniciar el servicio SSH."; exit 1; }
        log_action "Configurado AllowGroups sshusers en sshd_config y reiniciado SSH"
    fi
}

# Función para habilitar el servicio SSH
habilitar_ssh() {
    if systemctl is-active --quiet "$SERVICIO"; then
        echo "El servicio SSH ya está habilitado."
    else
        systemctl start "$SERVICIO" 2>/dev/null || { echo "Error: No se pudo iniciar el servicio SSH."; return 1; }
        systemctl enable "$SERVICIO" 2>/dev/null || { echo "Error: No se pudo habilitar el servicio SSH."; return 1; }
        echo "El servicio SSH ha sido habilitado."
        log_action "SSH habilitado"
    fi
}

# Función para deshabilitar el servicio SSH
deshabilitar_ssh() {
    if systemctl is-active --quiet "$SERVICIO"; then
        systemctl stop "$SERVICIO" 2>/dev/null || { echo "Error: No se pudo detener el servicio SSH."; return 1; }
        systemctl disable "$SERVICIO" 2>/dev/null || { echo "Error: No se pudo deshabilitar el servicio SSH."; return 1; }
        echo "El servicio SSH ha sido deshabilitado."
        log_action "SSH deshabilitado"
    else
        echo "El servicio SSH ya está deshabilitado."
    fi
}

# Función para ver el estado del servicio SSH
ver_estado_ssh() {
    if systemctl is-active --quiet "$SERVICIO"; then
        echo "El servicio SSH está activo."
    else
        echo "El servicio SSH está inactivo."
    fi
    log_action "Consultado estado de SSH"
}

# Función para gestionar usuarios autorizados
gestionar_usuarios() {
    echo "Gestión de usuarios para SSH:"
    PS3="Selecciona una opción: "
    options=("Añadir usuario" "Eliminar usuario" "Listar usuarios" "Cancelar")
    select OPCION in "${options[@]}"; do
        case "$OPCION" in
            "Añadir usuario")
                echo "Ingresa el nombre del usuario:"
                read -r USUARIO
                if [[ -z "$USUARIO" ]]; then
                    echo "Error: Nombre de usuario vacío"
                    continue
                fi
                if ! id "$USUARIO" >/dev/null 2>&1; then
                    echo "Error: El usuario '$USUARIO' no existe"
                    continue
                fi
                usermod -aG sshusers "$USUARIO"
                systemctl restart "$SERVICIO" 2>/dev/null || { echo "Error al reiniciar el servicio SSH."; return 1; }
                echo "Usuario '$USUARIO' añadido al grupo sshusers."
                log_action "Usuario $USUARIO añadido a sshusers"
                break
                ;;
            "Eliminar usuario")
                mapfile -t USUARIOS < <(getent group sshusers | cut -d: -f4 | tr ',' '\n')
                if [ ${#USUARIOS[@]} -eq 0 ]; then
                    echo "No hay usuarios en el grupo sshusers."
                    break
                fi
                echo "Usuarios en el grupo sshusers:"
                PS3="Selecciona el usuario a eliminar: "
                select USUARIO in "${USUARIOS[@]}" "Cancelar"; do
                    if [[ "$USUARIO" == "Cancelar" ]]; then
                        break 2
                    fi
                    [ -z "$USUARIO" ] && { echo "Error: Selección inválida"; continue; }
                    gpasswd -d "$USUARIO" sshusers
                    systemctl restart "$SERVICIO" 2>/dev/null || { echo "Error al reiniciar el servicio SSH."; return 1; }
                    echo "Usuario '$USUARIO' eliminado del grupo sshusers."
                    log_action "Usuario $USUARIO eliminado de sshusers"
                    break 2
                done
                ;;
            "Listar usuarios")
                mapfile -t USUARIOS < <(getent group sshusers | cut -d: -f4 | tr ',' '\n')
                if [ ${#USUARIOS[@]} -eq 0 ]; then
                    echo "No hay usuarios en el grupo sshusers."
                else
                    echo "Usuarios autorizados para SSH:"
                    for usuario in "${USUARIOS[@]}"; do
                        echo "- $usuario"
                    done
                fi
                log_action "Listados usuarios de sshusers"
                break
                ;;
            "Cancelar")
                break
                ;;
            *) echo "Opción inválida";;
        esac
    done
}

# Verificar e instalar SSH
verificar_ssh
determinar_servicio
configurar_ssh

# Menú principal
while true; do
    echo -e "\n=== Control de Acceso Remoto a SSH ==="
    PS3="Selecciona una opción: "
    options=("Habilitar SSH" "Deshabilitar SSH" "Ver estado de SSH" "Gestionar usuarios" "Salir")
    select opcion in "${options[@]}"; do
        case "$opcion" in
            "Habilitar SSH") habilitar_ssh;;
            "Deshabilitar SSH") deshabilitar_ssh;;
            "Ver estado de SSH") ver_estado_ssh;;
            "Gestionar usuarios") gestionar_usuarios;;
            "Salir") exit 0;;
            *) echo "Opción inválida";;
        esac
        break
    done
done