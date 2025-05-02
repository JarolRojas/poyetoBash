#!/bin/bash

# Función para monitorear recursos del sistema con opciones en Zenity
monitoreo_recursos() {
    opcion_monitoreo=$(zenity --list --title "Monitoreo de Recursos" --text "Selecciona una opción:" --column "Opciones" \
        "Resumen rápido" \
        "Uso actual de CPU y memoria" \
        "Uso del disco" \
        "Top procesos por CPU" \
        "Top procesos por RAM" \
        "Generar informe en un archivo")

    case $opcion_monitoreo in
        "Resumen rápido")
            echo -e "\n--- Resumen rápido de recursos---"
            top -b -n 1 | head -n 20
            ;;

        "Uso actual de CPU y memoria")
            echo -e "\n--- USO DE MEMORIA ---"
            free -h
            echo -e "\n--- USO DE CPU ---"
            mpstat 1 1
            ;;

        "Uso del disco")
            echo -e "\n--- USO DEL DISCO ---"
            df -h
            ;;

        "Top procesos por CPU")
            echo -e "\n--- TOP 5 PROCESOS POR CPU ---"
            ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
            ;;

        "Top procesos por RAM")
            echo -e "\n--- TOP 5 PROCESOS POR RAM ---"
            ps -eo pid,comm,%mem --sort=-%mem | head -n 6
            ;;

        "Generar informe en un archivo")
            ruta_archivo=$(zenity --file-selection --save --confirm-overwrite --title="Guardar Informe" --filename="monitoreo_reporte.txt")
            if [[ -n "$ruta_archivo" ]]; then
                echo "Generando informe en $ruta_archivo..."
                {
                    echo "### Informe de Recursos del Sistema ###"
                    echo
                    echo "USO DE MEMORIA:"
                    free -h
                    echo
                    echo "USO DE CPU:"
                    mpstat 1 1
                    echo
                    echo "USO DE DISCO:"
                    df -h
                    echo
                    echo "Top Procesos por CPU:"
                    ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
                    echo
                    echo "Top Procesos por RAM:"
                    ps -eo pid,comm,%mem --sort=-%mem | head -n 6
                } > "$ruta_archivo"
                echo "Informe guardado en: $ruta_archivo"
            else
                echo "No se guardó el informe."
            fi
            ;;

        *)
            echo "Opción no válida."
            ;;
    esac
}



# Función para administrar procesos con opciones en Zenity
admin_procesos() {
    opcion_procesos=$(zenity --list --title "Administración de Procesos" --text "Selecciona una opción:" --column "Opciones" \
        "Mostrar todos los procesos" \
        "Filtrar procesos por nombre" \
        "Terminar un proceso")
    
    case $opcion_procesos in
        "Mostrar todos los procesos")
            ps aux
            ;;
        "Filtrar procesos por nombre")
            nombre_proceso=$(zenity --entry --title "Filtrar Procesos" --text "Ingresa el nombre del proceso:")
            ps aux | grep "$nombre_proceso"
            ;;
        "Terminar un proceso")
            pid=$(zenity --entry --title "Terminar Proceso" --text "Ingresa el PID del proceso a terminar:")
            kill "$pid" && echo "Proceso $pid terminado." || echo "No se pudo terminar el proceso."
            ;;
        *)
            echo "Opción no válida."
            ;;
    esac
}

# Función para gestionar logs del sistema con opciones en Zenity
gestion_logs() {
    log_seleccionado=$(zenity --list --title "Gestión de Logs" --text "Selecciona un log:" --column "Logs" \
        "/var/log/syslog" \
        "/var/log/auth.log" \
        "/var/log/kern.log")
    
    if [ -n "$log_seleccionado" ]; then
        opcion_logs=$(zenity --list --title "Opciones de Logs" --text "Selecciona una opción para el log:" --column "Opciones" \
            "Mostrar contenido" \
            "Buscar en el log" \
            "Exportar el log a un archivo")
        
        case $opcion_logs in
            "Mostrar contenido")
                cat "$log_seleccionado"
                ;;
            "Buscar en el log")
                palabra_clave=$(zenity --entry --title "Buscar en el Log" --text "Ingresa una palabra clave para buscar:")
                grep "$palabra_clave" "$log_seleccionado"
                ;;
            "Exportar el log a un archivo")
                ruta_export=$(zenity --file-selection --save --confirm-overwrite --title="Exportar Log" --filename="log_export_$(basename "$log_seleccionado")")
                if [[ -n "$ruta_export" ]]; then
                    cp "$log_seleccionado" "$ruta_export"
                    zenity --info --title "Exportación Completa" --text "Log exportado a:\n$ruta_export"
                else
                zenity --warning --text="No se exportó ningún archivo."
                fi
                ;;
            *)
                echo "Opción no válida."
                ;;
        esac
    else
        zenity --error --title "Error" --text "No se seleccionó ningún log."
    fi
}

mandar_correo() {
    archivo_para_enviar=$(zenity --file-selection --title="Selecciona el archivo para enviar por correo")
    
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
        zenity --warning --text="No se seleccionó ningún archivo."
    fi
}

# Menú principal
while true; do
    opcion=$(zenity --list --title "Administración del Sistema" --text "Selecciona una opción:" --column "Opción" \
        "Monitoreo de recursos" \
        "Admin. de procesos" \
        "Gestión de logs" \
        "Mandar correo con info" \
        "Salir")

    case "$opcion" in
        "Monitoreo de recursos")
            monitoreo_recursos
            ;;
        "Admin. de procesos")
            admin_procesos
            ;;
        "Gestión de logs")
            gestion_logs
            ;;
        "Mandar correo con info")
            mandar_correo
            ;;
        "Salir")
            break
            ;;
        *)
            zenity --error --title "Error" --text "Opción no válida."
            ;;
    esac
done
