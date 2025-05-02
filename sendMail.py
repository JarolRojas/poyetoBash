import sys
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
import os

# Validación de argumentos
if len(sys.argv) != 3:
    print("Uso: python3 sendmail.py <archivo_a_enviar> <correo_destinatario>")
    sys.exit(1)

archivo = sys.argv[1]
destinatario = sys.argv[2]

# Configura tus credenciales de Gmail
remitente = "maipruebasclasecuatrovientos@gmail.com"
contrasena = "ekhp vtum ansx xrik"  # App password, no la contraseña real de Gmail

# Crear el mensaje
mensaje = MIMEMultipart()
mensaje['From'] = remitente
mensaje['To'] = destinatario
mensaje['Subject'] = "Archivo solicitado desde script de Linux"

# Cuerpo del mensaje
cuerpo = "Hola,\n\nAdjunto encontrarás el archivo solicitado.\n\nSaludos."
mensaje.attach(MIMEText(cuerpo, 'plain'))

# Adjuntar el archivo
try:
    with open(archivo, 'rb') as f:
        adjunto = MIMEApplication(f.read(), Name=os.path.basename(archivo))
        adjunto['Content-Disposition'] = f'attachment; filename="{os.path.basename(archivo)}"'
        mensaje.attach(adjunto)
except FileNotFoundError:
    print(f"Error: El archivo {archivo} no se encontró.")
    sys.exit(1)

# Enviar el correo
try:
    servidor = smtplib.SMTP('smtp.gmail.com', 587)
    servidor.starttls()
    servidor.login(remitente, contrasena)
    servidor.send_message(mensaje)
    servidor.quit()
    print(f"Correo enviado exitosamente a {destinatario}")
except Exception as e:
    print(f"Error al enviar el correo: {e}")
    sys.exit(1)