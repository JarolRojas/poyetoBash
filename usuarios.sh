#!/bin/bash
# Script de gestión de usuarios con Zenity y log de cambios

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    zenity --error --text="Este script debe ejecutarse con sudo"
    exit 1
fi

# Verificar si Zenity está instalado
command -v zenity >/dev/null 2>&1 || { echo "Error: Zenity no está instalado. Instálalo con: sudo apt install zenity"; exit 1; }

# Archivo de log con timestamp
LOG_FILE="/var/log/user_management_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Función para registrar cambios
log_cambio() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Función para validar entrada
validar_entrada() {
    if [[ "$1" =~ [^a-zA-Z0-9_-] ]]; then
        zenity --error --text="Solo se permiten letras, números, guiones y guiones bajos en '$1'"
        return 1
    fi
    return 0
}

crear_usuario() {
    # Mostrar usuarios existentes
    USUARIOS_EXISTENTES=$(cut -d: -f1 /etc/passwd | sort | zenity --list --title="Usuarios Existentes" --column="Usuarios" --width=300 --height=400 --text="Usuarios existentes (solo información):")
    USUARIO=$(zenity --entry --title="Crear Usuario" --text="Ingrese el nombre de usuario (nuevo, no debe existir en la lista):")
    [ -z "$USUARIO" ] && { zenity --error --text="El nombre de usuario no puede estar vacío"; return 1; }
    validar_entrada "$USUARIO" || return 1
    if id "$USUARIO" >/dev/null 2>&1; then
        zenity --error --text="El usuario '$USUARIO' ya existe"
        return 1
    fi
    
    CONTRASENA=$(zenity --password --title="Contraseña para $USUARIO")
    [ -z "$CONTRASENA" ] && { zenity --error --text="La contraseña no puede estar vacía"; return 1; }
    
    if ! useradd -m -s /bin/bash "$USUARIO"; then
        zenity --error --text="No se pudo crear el usuario '$USUARIO'. Verifica permisos o espacio."
        return 1
    fi
    if ! echo "$USUARIO:$CONTRASENA" | chpasswd; then
        zenity --error --text="No se pudo establecer la contraseña para '$USUARIO'"
        userdel "$USUARIO"
        return 1
    fi
    log_cambio "Usuario '$USUARIO' creado"
    zenity --info --text="Usuario '$USUARIO' creado con éxito"
}

eliminar_usuario() {
    USUARIO=$(cut -d: -f1 /etc/passwd | sort | zenity --list --title="Eliminar Usuario" --column="Usuarios" --width=300 --height=400 --text="Seleccione el usuario a eliminar:")
    [ -z "$USUARIO" ] && { zenity --error --text="No se seleccionó ningún usuario"; return 1; }
    if ! id "$USUARIO" >/dev/null 2>&1; then
        zenity --error --text="El usuario '$USUARIO' no existe"
        return 1
    fi
    
    zenity --question --text="¿Eliminar a '$USUARIO'?" || { zenity --info --text="Eliminación cancelada"; return 1; }
    if ! userdel -r "$USUARIO" 2>/dev/null; then
        zenity --error --text="No se pudo eliminar '$USUARIO'. Verifica permisos o archivos en uso."
        return 1
    fi
    log_cambio "Usuario '$USUARIO' eliminado"
    zenity --info --text="Usuario '$USUARIO' eliminado con éxito"
}

restablecer_contraseña() {
    USUARIO=$(cut -d: -f1 /etc/passwd | sort | zenity --list --title="Restablecer Contraseña" --column="Usuarios" --width=300 --height=400 --text="Seleccione el usuario para restablecer la contraseña:")
    [ -z "$USUARIO" ] && { zenity --error --text="No se seleccionó ningún usuario"; return 1; }
    if ! id "$USUARIO" >/dev/null 2>&1; then
        zenity --error --text="El usuario '$USUARIO' no existe"
        return 1
    fi
    
    CONTRASENA=$(zenity --password --title="Nueva contraseña para $USUARIO")
    [ -z "$CONTRASENA" ] && { zenity --error --text="La contraseña no puede estar vacía"; return 1; }
    
    if ! echo "$USUARIO:$CONTRASENA" | chpasswd; then
        zenity --error --text="No se pudo restablecer la contraseña para '$USUARIO'"
        return 1
    fi
    log_cambio "Contraseña de '$USUARIO' restablecida"
    zenity --info --text="Contraseña de '$USUARIO' restablecida con éxito"
}

listar_usuarios() {
    cut -d: -f1 /etc/passwd | sort | zenity --list --title="Usuarios del Sistema" --column="Usuarios" --width=300 --height=400
}

gestionar_permisos() {
    USUARIO=$(cut -d: -f1 /etc/passwd | sort | zenity --list --title="Gestionar Permisos" --column="Usuarios" --width=300 --height=400 --text="Seleccione el usuario para gestionar permisos:")
    [ -z "$USUARIO" ] && { zenity --error --text="No se seleccionó ningún usuario"; return 1; }
    if ! id "$USUARIO" >/dev/null 2>&1; then
        zenity --error --text="El usuario '$USUARIO' no existe"
        return 1
    fi
    
    GRUPO=$(cut -d: -f1 /etc/group | sort | zenity --list --title="Seleccione un grupo" --column="Grupos" --width=300 --height=400)
    [ -z "$GRUPO" ] && { zenity --error --text="No se seleccionó ningún grupo"; return 1; }
    
    OPCION=$(zenity --list --title="Seleccionar Acción" --column="Acción" "Añadir al grupo" "Quitar del grupo")
    case "$OPCION" in
        "Añadir al grupo")
            if ! usermod -aG "$GRUPO" "$USUARIO"; then
                zenity --error --text="No se pudo añadir '$USUARIO' al grupo '$GRUPO'"
                return 1
            fi
            log_cambio "'$USUARIO' añadido al grupo '$GRUPO'"
            zenity --info --text="'$USUARIO' añadido al grupo '$GRUPO'"
            ;;
        "Quitar del grupo")
            if ! gpasswd -d "$USUARIO" "$GRUPO"; then
                zenity --error --text="No se pudo quitar '$USUARIO' del grupo '$GRUPO'"
                return 1
            fi
            log_cambio "'$USUARIO' quitado del grupo '$GRUPO'"
            zenity --info --text="'$USUARIO' quitado del grupo '$GRUPO'"
            ;;
        *) zenity --error --text="Acción cancelada"; return 1;;
    esac
}

enviar_info_usuario() {
    archivo_para_enviar="$LOG_FILE"
    if [[ -n "$archivo_para_enviar" ]]; then
        destinatario=$(zenity --entry --title="Enviar Correo" --text="Ingresa el correo del destinatario:")
        if [[ -n "$destinatario" ]]; then
            echo "Enviando $archivo_para_enviar a $destinatario..."
            python3 sendMail.py "$archivo_para_enviar" "$destinatario"
            if [[ $? -eq 0 ]]; then
                zenity --info --title="Correo Enviado" --text="El correo fue enviado correctamente a $destinatario"
            else
                zenity --error --title="Error" --text="Ocurrió un error al enviar el correo."
            fi
        else
            zenity --warning --text="No se ingresó un correo."
        fi
    else
        zenity --warning --text="No hay archivo de log para enviar."
    fi
}

# Menú principal
while true; do
    opcion=$(zenity --list --title="Gestión de Usuarios" --column="Opción" --column="Acción" \
        1 "Crear Usuario" 2 "Eliminar Usuario" 3 "Restablecer Contraseña" \
        4 "Listar Usuarios" 5 "Gestionar Permisos" 6 "Enviar Info por Correo" 7 "Salir" --height=300)
    case "$opcion" in
        1) crear_usuario;;
        2) eliminar_usuario;;
        3) restablecer_contraseña;;
        4) listar_usuarios;;
        5) gestionar_permisos;;
        6) enviar_info_usuario;;
        7) exit 0;;
        *) zenity --error --text="Opción inválida";;
    esac
done