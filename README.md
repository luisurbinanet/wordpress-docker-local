# WordPress Docker Setup

Este repositorio contiene la configuración y los scripts necesarios para levantar un entorno de WordPress utilizando Docker. Incluye contenedores para WordPress, MySQL, Traefik como reverse proxy, y certificados SSL autofirmados.

## 🚀 Características

- ✅ Configuración automática de WordPress con Docker Compose
- ✅ Traefik como reverse proxy con SSL/TLS
- ✅ Certificados SSL autofirmados generados automáticamente
- ✅ phpMyAdmin para gestión de base de datos
- ✅ Configuración estática de Traefik (solución para problemas en WSL2)
- ✅ Redirección automática HTTP → HTTPS
- ✅ Scripts de instalación y gestión automatizados
- ✅ Soporte para múltiples proyectos WordPress
- ✅ Authentication Keys and Salts generadas automáticamente
- ✅ Configuración JWT Authentication incluida
- ✅ Configuración Google reCAPTCHA V3 incluida

## 📋 Requisitos

- [Docker](https://docs.docker.com/get-docker/)
- [docker-compose](https://docs.docker.com/compose/install/)
- Bash (Linux o WSL)
- OpenSSL (para generar certificados)

## 📁 Estructura del Repositorio

```
wordpress-docker-local/
├── create_wp_site.sh          # Script para crear nuevos sitios WordPress
├── install_wp_stack.sh        # Script de instalación inicial del entorno Docker
├── README.md                  # Esta documentación
├── .gitignore                 # Archivos ignorados por Git
└── template/                  # Plantilla base para nuevos proyectos
    ├── docker-compose.yml     # Definición de los servicios Docker
    ├── traefik.yml            # Configuración estática de Traefik
    ├── .env.example           # Plantilla de variables de entorno
    └── scripts/
        └── create_wp_site.sh  # Script base para crear sitios
```

## 🔧 Instalación Inicial

1. **Clonar o descargar el repositorio**

   ```bash
   git clone <url-del-repositorio>
   cd wordpress-docker-local
   ```

2. **Configurar el entorno Docker**

   Ejecuta el script de instalación para crear la estructura de directorios, colocar los archivos base y generar un certificado autofirmado:

   ```bash
   ./install_wp_stack.sh
   ```

   Este script:
   - Añade el usuario al grupo `docker` (si no lo está).
   - Crea la estructura de directorios en `~/projects/wordpress/` y copia los archivos de configuración.
   - Genera certificados autofirmados en `template/certs`.
   
   **Nota:** Los proyectos se crean en `~/projects/wordpress/` que está vinculado a tu carpeta de Windows (`/mnt/c/Users/luisu/dev-projects/wordpress/`) para respaldo automático de datos. Si `~/projects` no existe, el script lo creará automáticamente.

3. **Verificar la instalación**

   Verifica que se haya creado la estructura:

   ```bash
   ls -la ~/projects/wordpress/template/
   ```

## 🆕 Crear un Nuevo Sitio WordPress

Para crear un nuevo proyecto WordPress:

1. **Ejecuta el script de creación:**

   ```bash
   ./create_wp_site.sh nombre-del-sitio
   ```

   Donde `nombre-del-sitio` es el nombre que se usará para:
   - El directorio del proyecto.
   - Las variables de entorno en el archivo `.env` (como `PROJECT_NAME` y `DOMAIN`).
   - El dominio del sitio (ej: `nombre-del-sitio.test`)

2. **Estructura del proyecto creado:**

   ```
   ~/projects/wordpress/nombre-del-sitio/
   ├── docker-compose.yml      # Configuración Docker del proyecto
   ├── traefik.yml             # Configuración estática de Traefik
   ├── .env                    # Variables de entorno del proyecto
   ├── start.sh                # Script para iniciar el proyecto
   ├── stop.sh                 # Script para detener el proyecto
   ├── certs/                  # Certificados SSL del proyecto
   │   ├── cert.pem
   │   └── key.pem
   ├── data/
   │   ├── mysql/              # Datos persistentes de MySQL
   │   └── wordpress/          # Archivos de WordPress
   │       ├── wp-config.php
   │       └── wp-content/
   └── letsencrypt/            # Certificados Let's Encrypt (si se usan)
   ```

## 🚀 Levantar y Detener el Sitio

### Iniciar el entorno

Cambia al directorio del proyecto y ejecuta:

```bash
cd ~/projects/wordpress/nombre-del-sitio
./start.sh
```

O manualmente:

```bash
cd ~/projects/wordpress/nombre-del-sitio
docker-compose up -d
```

### Detener el entorno

Dentro del directorio del proyecto, ejecuta:

```bash
./stop.sh
```

O manualmente:

```bash
docker-compose down
```

### Ver logs

```bash
# Logs de todos los servicios
docker-compose logs -f

# Logs de un servicio específico
docker-compose logs -f wordpress
docker-compose logs -f traefik
docker-compose logs -f db
```

## 🌐 Acceder a los Servicios

Una vez iniciado el proyecto, puedes acceder a:

- **WordPress:** `https://nombre-del-sitio.test`
- **phpMyAdmin:** `https://pma.nombre-del-sitio.test`

**Nota:** Los certificados SSL son autofirmados, por lo que tu navegador mostrará una advertencia de seguridad. Esto es normal en desarrollo local. Acepta la excepción para continuar.

## 🔍 Solución de Problemas

### Error 404 al acceder al sitio

Si obtienes un error 404 al acceder al sitio, puede ser debido a problemas de conexión de Traefik con Docker en WSL2. Este proyecto incluye una **configuración estática de Traefik** (`traefik.yml`) que soluciona este problema.

**Solución:**

1. Verifica que los contenedores estén corriendo:
   ```bash
   docker-compose ps
   ```

2. Verifica los logs de Traefik:
   ```bash
   docker-compose logs traefik
   ```

3. Si Traefik no puede conectarse al socket de Docker, la configuración estática (`traefik.yml`) debería funcionar automáticamente. Si el problema persiste:
   ```bash
   docker-compose restart traefik
   ```

4. Reinicia Docker Desktop (si usas WSL2):
   - Cierra Docker Desktop completamente
   - Vuelve a abrirlo
   - Espera a que esté completamente iniciado
   - Reinicia los contenedores: `docker-compose restart`

### Problemas con certificados SSL

Si hay problemas con los certificados:

1. Regenera los certificados:
   ```bash
   cd ~/projects/wordpress/nombre-del-sitio
   rm -f certs/cert.pem certs/key.pem
   openssl req -newkey rsa:2048 -nodes \
     -keyout certs/key.pem \
     -x509 -days 365 -out certs/cert.pem \
     -subj "/CN=nombre-del-sitio.test" \
     -addext "subjectAltName=DNS:nombre-del-sitio.test,DNS:pma.nombre-del-sitio.test,DNS:*.nombre-del-sitio.test,IP:127.0.0.1"
   chmod 644 certs/cert.pem
   chmod 600 certs/key.pem
   docker-compose restart traefik
   ```

### Problemas con permisos

Si hay problemas con permisos en los directorios:

```bash
cd ~/projects/wordpress/nombre-del-sitio
sudo chown -R $USER:$USER data/ certs/
chmod -R 755 data/
chmod 644 certs/cert.pem
chmod 600 certs/key.pem
```

### La base de datos no inicia

Si MySQL no inicia correctamente:

1. Verifica los logs:
   ```bash
   docker-compose logs db
   ```

2. Si hay problemas de permisos, elimina los datos y reinicia:
   ```bash
   docker-compose down
   sudo rm -rf data/mysql/*
   docker-compose up -d
   ```

## 📝 Notas Adicionales

### Ubicación de proyectos

Los proyectos se crean en `~/projects/wordpress/` que está vinculado a tu carpeta de Windows para respaldo automático. Si `~/projects` no existe, el script de instalación lo creará automáticamente.

### Hosts en WSL

Si ejecutas estos scripts en WSL, se configurará automáticamente el archivo `/etc/hosts` para que los dominios (por ejemplo, `nombre-del-sitio.test`) apunten a `127.0.0.1`.

### Certificados SSL

Los certificados generados son autofirmados y válidos para desarrollo local. Si necesitas certificados válidos para producción, puedes:

1. Reemplazar los certificados en `certs/` con certificados válidos
2. Configurar Let's Encrypt (requiere un dominio real y configuración adicional)

### Configuración de Traefik

Este proyecto usa una **configuración híbrida** de Traefik:
- **Provider Docker:** Para descubrimiento automático de servicios (puede no funcionar en WSL2)
- **Provider File:** Configuración estática en `traefik.yml` (funciona siempre)

La configuración estática tiene prioridad y asegura que los servicios funcionen incluso si el provider de Docker tiene problemas.

### Variables de entorno

Cada proyecto tiene su propio archivo `.env` con las siguientes variables:

```env
# Project Settings
PROJECT_NAME=nombre-del-sitio
DOMAIN=nombre-del-sitio.test
ACME_EMAIL=your-email@example.com

# Database
DB_NAME=nombre-del-sitio_db
DB_USER=wp_user
DB_PASSWORD=Wp@SecurePass123
DB_ROOT_PASSWORD=Root@SecurePass123

# WordPress
WP_DEBUG=1
WP_ENV=development

# JWT Authentication
JWT_AUTH_SECRET_KEY=your-jwt-secret-key-here
JWT_AUTH_CORS_ENABLE=true

# Google reCAPTCHA V3
RECAPTCHA_SITE_KEY=your-recaptcha-site-key-here
RECAPTCHA_SECRET_KEY=your-recaptcha-secret-key-here
```

**Nota:** 
- El `JWT_AUTH_SECRET_KEY` se genera **automáticamente** para cada nueva instalación (64 caracteres aleatorios).
- Las claves de reCAPTCHA se generan como placeholders automáticamente. Para usar reCAPTCHA en producción, reemplázalas con tus claves reales de [Google reCAPTCHA](https://www.google.com/recaptcha/admin).

### Configuración de wp-config.php

Cada proyecto WordPress incluye automáticamente en `wp-config.php`:

1. **Authentication Unique Keys and Salts:** Generadas automáticamente desde la API de WordPress o usando OpenSSL
2. **JWT Authentication Configuration:** Para autenticación mediante tokens JWT
3. **Google reCAPTCHA V3 Configuration:** Para protección contra spam y bots

Estas configuraciones se agregan automáticamente al crear un nuevo proyecto.

## 🔒 Seguridad

- ⚠️ **Este setup es para desarrollo local únicamente**
- ⚠️ Las contraseñas por defecto son débiles - cámbialas en producción
- ⚠️ Los certificados SSL son autofirmados - no usar en producción
- ⚠️ No exponer los puertos 80/443 al público sin configuración adicional

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 🙏 Agradecimientos

- [WordPress](https://wordpress.org/)
- [Traefik](https://traefik.io/)
- [Docker](https://www.docker.com/)

---

**¿Problemas o preguntas?** Abre un issue en el repositorio de GitHub.
