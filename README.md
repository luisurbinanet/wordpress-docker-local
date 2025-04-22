# WordPress Docker Setup

Este repositorio contiene la configuración y los scripts necesarios para levantar un entorno de WordPress utilizando Docker. Incluye contenedores para WordPress, MySQL, y certificados SSL.

## Requisitos

- [Docker](https://docs.docker.com/get-docker/)
- [docker-compose](https://docs.docker.com/compose/install/)
- Bash (Linux o WSL)

## Estructura del Repositorio

```
create_wp_site.sh          # Script para crear nuevos sitios WordPress
install_wp_stack.sh        # Script de instalación inicial del entorno Docker
template/
  docker-compose.yml       # Definición de los servicios y redes de Docker
  certs/                   # Certificados SSL
    cert.pem               # Certificado SSL autofirmado
    key.pem                # Llave privada del certificado
  data/                    # Directorios de datos persistentes
    mysql/                 # Datos de MySQL
    wordpress/             # Archivos de WordPress
  scripts/
    create_wp_site.sh      # Script base para crear un nuevo sitio WordPress
```

## Instalación Inicial

1. **Configurar el entorno Docker y permisos**

   Ejecuta el script de instalación para crear la estructura de directorios, colocar los archivos base y generar un certificado autofirmado:

   ```bash
   ./install_wp_stack.sh
   ```

   Este script:
   - Añade el usuario al grupo `docker` (si no lo está).
   - Crea la estructura de directorios y copia los archivos de configuración.
   - Genera certificados autofirmados en `template/certs`.

2. **Ignorar los certificados**

   Nota: Los certificados (`cert.pem` y `key.pem`) están añadidos al archivo `.gitignore` para que no sean versionados.

## Crear un Nuevo Sitio WordPress

Para crear un nuevo proyecto WordPress:

1. Ejecuta el script de creación:

   ```bash
   ./create_wp_site.sh nombre-del-sitio
   ```

   Donde `nombre-del-sitio` es el nombre que se usará para:
   - El directorio del proyecto.
   - Las variables de entorno en el archivo `.env` (como `PROJECT_NAME` y `DOMAIN`).

2. Dentro del directorio creado, encontrarás:
   - Un archivo `docker-compose.yml` adaptado al proyecto.
   - Un archivo `.env` configurado.
   - Scripts de utilidad: `start.sh` para levantar y `stop.sh` para detener los contenedores.

## Levantar y Detener el Sitio

- **Iniciar el entorno:**

  Cambia al directorio del proyecto y ejecuta:

  ```bash
  cd ~/docker/wordpress/nombre-del-sitio
  ./start.sh
  ```

- **Detener el entorno:**

  Dentro del directorio del proyecto, ejecuta:

  ```bash
  ./stop.sh
  ```

## Notas Adicionales

- **Hosts en WSL:**  
  Si ejecutas estos scripts en WSL, se configurará automáticamente el archivo `/etc/hosts` para que los dominios (por ejemplo, `nombre-del-sitio.test`) apunten a `127.0.0.1`.

- **Certificados SSL:**  
  Los certificados generados son autofirmados. Si necesitas certificados válidos, puedes reemplazarlos en `template/certs`.

---

Con estos pasos deberías poder configurar y desplegar nuevos sitios WordPress usando Docker de manera sencilla. Cualquier error o duda, dejalo en los comentarios
