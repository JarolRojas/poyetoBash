#!/bin/bash
#Script para controlar el acceso remoto a un servidor Linux
#Verifica si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi
#Verifica si Zenity está instalado
if ! command -v zenity &> /dev/null; then
    echo "Zenity no está instalado. Instalalo con: sudo apt install zenity"
    exit 1
fi
#Función para mostrar el menú de opciones
mostrar_menu() {
    zenity --list --title="Control de Acceso Remoto" --column="Opciones" \
    "Habilitar SSH" \
    "Deshabilitar SSH" \
    "Ver estado de SSH" \
    "Configurar Firewall" \
    "Salir"
}
#Función para habilitar el servicio SSH 
habilitar_ssh() {
    if systemctl is-active --quiet ssh; then
        zenity --info --text="El servicio SSH ya está habilitado."
    else
        systemctl start ssh
        systemctl enable ssh
        zenity --info --text="El servicio SSH ha sido habilitado."
    fi
}
#Función para deshabilitar el servicio SSH
deshabilitar_ssh() {
    if systemctl is-active --quiet ssh; then
        systemctl stop ssh
        systemctl disable ssh
        zenity --info --text="El servicio SSH ha sido deshabilitado."
    else
        zenity --info --text="El servicio SSH ya está deshabilitado."
    fi
}
#Función para ver el estado del servicio SSH
ver_estado_ssh() {
    if systemctl is-active --quiet ssh; then
        zenity --info --text="El servicio SSH está activo."
    else
        zenity --info --text="El servicio SSH está inactivo."
    fi
}
#Función para configurar el firewall
configurar_firewall() {
    if ! command -v ufw &> /dev/null; then
        zenity --error --text="UFW no está instalado. Instalalo con: sudo apt install ufw"
        return
    fi
    if zenity --question --text="¿Deseas habilitar el firewall?" --ok-label="Sí" --cancel-label="No"; then
        ufw enable
        zenity --info --text="El firewall ha sido habilitado."
    else
        ufw disable
        zenity --info --text="El firewall ha sido deshabilitado."
    fi
}
#Función principal
main() {
    while true; do
        OPCION=$(mostrar_menu)
        case $OPCION in
            "Habilitar SSH")
                habilitar_ssh
                ;;
            "Deshabilitar SSH")
                deshabilitar_ssh
                ;;
            "Ver estado de SSH")
                ver_estado_ssh
                ;;
            "Configurar Firewall")
                configurar_firewall
                ;;
            "Salir")
                exit 0
                ;;
            *)
                zenity --error --text="Opción no válida."
                ;;
        esac
    done
}
#Llamada a la función principal
main

