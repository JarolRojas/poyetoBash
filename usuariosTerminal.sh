#!/bin/bash
# Script de gestión de usuarios en terminal con log de cambios

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse con sudo"
    exit 1
fi

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
        echo "Solo se permiten letras, números, guiones y guiones bajos en '$1'"
        return 1
    fi
    return 0
}

crear_usuario() {
    echo "Usuarios existentes:"
    cut -d: -f1 /etc/passwd | sort
    read -p "Ingrese el nombre de usuario (nuevo, no debe existir en la lista): " USUARIO
    [ -z "$USUARIO" ] && { echo "El nombre de usuario no puede estar vacío"; return 1; }
    validar_entrada "$USUARIO" || return 1
    if id "$USUARIO" >/dev/null 2>&1; then
        echo "El usuario '$USUARIO' ya existe"
        return 1
    fi
    
    read -s -p "Contraseña para $USUARIO: " CONTRASENA
    echo
    [ -z "$CONTRASENA" ] && { echo "La contraseña no puede estar vacía"; return 1; }
    
    if ! useradd -m -s /bin/bash "$USUARIO"; then
        echo "No se pudo crear el usuario '$USUARIO'. Verifica permisos o espacio."
        return 1
    fi
    if ! echo "$USUARIO:$CONTRASENA" | chpasswd; then
        echo "No se pudo establecer la contraseña para '$USUARIO'"
        userdel "$USUARIO"
        return 1
    fi
    log_cambio "Usuario '$USUARIO' creado"
    echo "Usuario '$USUARIO' creado con éxito"
}

eliminar_usuario() {
    echo "Usuarios del sistema:"
    select USUARIO in $(cut -d: -f1 /etc/passwd | sort); do
        if [ -n "$USUARIO" ]; then
            read -p "¿Eliminar a '$USUARIO'? (s/n): " CONFIRMACION
            if [ "$CONFIRMACION" = "s" ]; then
                if ! userdel -r "$USUARIO" 2>/dev/null; then
                    echo "No se pudo eliminar '$USUARIO'. Verifica permisos o archivos en uso."
                    return 1
                fi
                log_cambio "Usuario '$USUARIO' eliminado"
                echo "Usuario '$USUARIO' eliminado con éxito"
            else
                echo "Eliminación cancelada"
            fi
            break
        else
            echo "Selección inválida"
        fi
    done
}

restablecer_contraseña() {
    echo "Usuarios del sistema:"
    select USUARIO in $(cut -d: -f1 /etc/passwd | sort); do
        if [ -n "$USUARIO" ]; then
            read -s -p "Nueva contraseña para $USUARIO: " CONTRASENA
            echo
            [ -z "$CONTRASENA" ] && { echo "La contraseña no puede estar vacía"; return 1; }
            if ! echo "$USUARIO:$CONTRASENA" | chpasswd; then
                echo "No se pudo restablecer la contraseña para '$USUARIO'"
                return 1
            fi
            log_cambio "Contraseña de '$USUARIO' restablecida"
            echo "Contraseña de '$USUARIO' restablecida con éxito"
            break
        else
            echo "Selección inválida"
        fi
    done
}

listar_usuarios() {
    echo "Usuarios del sistema:"
    cut -d: -f1 /etc/passwd | sort
}

gestionar_permisos() {
    echo "Usuarios del sistema:"
    select USUARIO in $(cut -d: -f1 /etc/passwd | sort); do
        if [ -n "$USUARIO" ]; then
            echo "Grupos del sistema:"
            select GRUPO in $(cut -d: -f1 /etc/group | sort); do
                if [ -n "$GRUPO" ]; then
                    echo "1. Añadir al grupo"
                    echo "2. Quitar del grupo"
                    read -p "Seleccione una acción: " OPCION
                    case "$OPCION" in
                        1)
                            if ! usermod -aG "$GRUPO" "$USUARIO"; then
                                echo "No se pudo añadir '$USUARIO' al grupo '$GRUPO'"
                                return 1
                            fi
                            log_cambio "'$USUARIO' añadido al grupo '$GRUPO'"
                            echo "'$USUARIO' añadido al grupo '$GRUPO'"
                            ;;
                        2)
                            if ! gpasswd -d "$USUARIO" "$GRUPO"; then
                                echo "No se pudo quitar '$USUARIO' del grupo '$GRUPO'"
                                return 1
                            fi
                            log_cambio "'$USUARIO' quitado del grupo '$GRUPO'"
                            echo "'$USUARIO' quitado del grupo '$GRUPO'"
                            ;;
                        *) echo "Acción inválida";;
                    esac
                    break
                else
                    echo "Selección de grupo inválida"
                fi
            done
            break
        else
            echo "Selección de usuario inválida"
        fi
    done
}

enviar_info_usuario() {
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

# Menú principal
while true; do
    echo "Gestión de Usuarios"
    echo "1. Crear Usuario"
    echo "2. Eliminar Usuario"
    echo "3. Restablecer Contraseña"
    echo "4. Listar Usuarios"
    echo "5. Gestionar Permisos"
    echo "6. Enviar Info por Correo"
    echo "7. Salir"
    read -p "Seleccione una opción: " opcion
    case "$opcion" in
        1) crear_usuario;;
        2) eliminar_usuario;;
        3) restablecer_contraseña;;
        4) listar_usuarios;;
        5) gestionar_permisos;;
        6) enviar_info_usuario;;
        7) exit 0;;
        *) echo "Opción inválida";;
    esac
done