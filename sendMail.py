import smtplib
from email.mime.text import MIMEText
import sys

def enviar_correo(usuario, destinatario, info):
    try:
        # Configuración del servidor SMTP
        mail_server = smtplib.SMTP('smtp.gmail.com', 587)
        mail_server.starttls()
        mail_server.ehlo()
        mail_server.login('maitesolam@gmail.com', 'cyxs kvkw fmvu lhrf')  # Usa una contraseña de aplicación segura

        # Crear el mensaje
        mensaje = MIMEText(f"Información de '{usuario}': {info}")
        mensaje['From'] = 'maitesolam@gmail.com'
        mensaje['To'] = destinatario
        mensaje['Subject'] = f'Información de usuario: {usuario}'

        # Enviar el correo
        mail_server.sendmail('maitesolam@gmail.com', destinatario, mensaje.as_string())
        mail_server.quit()
        return True
    except Exception as e:
        print(f"Error al enviar el correo: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Uso: python3 enviar_correo.py <usuario> <destinatario> <info>")
        sys.exit(1)
    
    usuario = sys.argv[1]
    destinatario = sys.argv[2]
    info = sys.argv[3]
    
    if enviar_correo(usuario, destinatario, info):
        sys.exit(0)
    else:
        sys.exit(1)
