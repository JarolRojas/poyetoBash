=== README ===

Nombre del Programa: Suite de Administración de Sistemas Linux

Descripción:
Este programa es una suite de herramientas diseñada para facilitar la administración de sistemas Linux. Incluye módulos para gestión de usuarios, seguridad, red, administración del sistema y conexión remota, todo integrado en un menú principal fácil de usar.

Características Principales:
- Gestión de usuarios: Crear, eliminar, restablecer contraseñas y gestionar permisos.
- Gestión de seguridad: Copias de seguridad, firewall, análisis de vulnerabilidades.
- Gestión de red: Configuración de interfaces, diagnóstico y monitoreo.
- Administración del sistema: Monitoreo de recursos, procesos y logs.
- Conexión remota: Configuración SSH y conexiones remotas.

Requisitos:
- Sistema operativo: Linux (probado en distribuciones basadas en Debian/Ubuntu).
- Ejecución como root (se requieren permisos administrativos).
- Dependencias: Zenity, Python3, OpenSSH, UFW, Lynis, sysstat, ethtool, ipcalc.

Instalación:
1. Descargar todos los archivos del programa en un mismo directorio.
2. Ejecutar el script de instalación con permisos de root:
   sudo ./install.sh
3. Seguir las instrucciones en pantalla para completar la instalación.

Uso:
1. Ejecutar el menú principal:
   sudo ./scriptsPrograma/menuPrincipal.sh
2. Seleccionar la opción deseada del menú.
3. Seguir las instrucciones específicas de cada módulo.

Estructura de Archivos:
- install.sh: Script de instalación de dependencias.
- menuPrincipal.sh: Menú principal de la aplicación.
- usuarios.sh: Gestión de usuarios.
- seguridad.sh: Herramientas de seguridad.
- red.sh: Gestión de red.
- adminSistemas.sh: Administración del sistema.
- conexionRemota.sh / remoto.sh: Conexión remota y configuración SSH.
- sendMail.py: Script auxiliar para envío de correos.

Notas:
- Todos los scripts deben tener permisos de ejecución (chmod +x).
- Se recomienda revisar los logs generados en /var/log/ para seguimiento de acciones.
- Las credenciales de correo en sendMail.py deben actualizarse según necesidad.

Licencia:
Este software se distribuye bajo licencia libre. Se permite su uso y modificación siempre que se mantenga esta nota de licencia.

Contacto:
Para soporte o contribuciones, contactar con el desarrollador.

=== FIN DEL README ===