#!/bin/bash

#Funcion Volver

Volver(){
#Comando para regresar a el menu (si el menu tiene un bucle While con el break es suficiente)
echo ""
}

#Funcion Historial Conexiones

Historial(){
    username=$(zenity --entry --title="Historial de Conexiones SSH" --text="Ingrese su nombre de usuario:")

    if [ -z "$username" ]; then
       zenity --error --text="No se ingresó un nombre de usuario."
       exit 1
    fi


    conexion=$(grep "sshd.*$username" "/var/log/auth.log" | grep "Accepted" | awk '{print $11}' | sort | uniq)

    if [ -z "$conexion" ]; then
        zenity --info --text="No se encontraron conexiones SSH para el usuario $username."
    else
        zenity --text-info --title="Historial de Conexiones SSH" --width=400 --height=300 --text="$conexion"
    fi
}

#Funcion Conexion

Conexion(){
    opcion=$(zenity --forms --title="Inserte los Datos" --text="Complete El Siguentes Campos:" --add-entry="Usuario" --add-entry="IP")

    if [ $? -eq 0 ]
    then
        IFS=$'|' read -r usuario ip <<< "$opcion"
        ssh $usuario@$ip
    else
        echo "error"
    fi
}

#menu

while true
do

opcion=$(zenity --list --title="Conexion Remota" --column="Opcion" --column="Accion" 1 "Conexion R" 2 "Historial" 3 "Volver")

case $opcion in
1)Conexion;;
2)Historial;;
3)Volver
break
;;
*)zenity --error --text="Opcion No Valida";;
esac

done

#Intalar SSH