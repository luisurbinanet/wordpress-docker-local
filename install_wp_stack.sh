#!/bin/bash
set -e

echo "🚀 Configurando entorno Docker para WordPress"

# Verificar requisitos
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado. Por favor instala Docker primero."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose no está instalado. Por favor instálalo primero."
    exit 1
fi

# 1. Configurar permisos de Docker
if ! groups | grep -q docker; then
    echo "🔧 Añadiendo usuario al grupo docker..."
    sudo usermod -aG docker $USER
    newgrp docker
fi

# 2. Crear estructura de directorios
# Asegurar que ~/projects existe (puede ser un enlace simbólico a Windows)
if [ ! -d "$HOME/projects" ]; then
    echo "📁 Creando directorio ~/projects..."
    mkdir -p "$HOME/projects"
fi

echo "📁 Creando estructura de directorios en ~/projects/wordpress..."
mkdir -p ~/projects/wordpress/template/{data/{mysql,wordpress},scripts,certs}

# Archivo docker-compose.yml
cat > ~/projects/wordpress/template/docker-compose.yml <<'EOL'
version: '3.8'

services:
  wordpress:
    image: wordpress:php8.2-apache
    container_name: ${PROJECT_NAME}_wp
    restart: unless-stopped
    env_file: .env
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
      WORDPRESS_DB_NAME: ${DB_NAME}
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_HOME', 'https://${DOMAIN}');
        define('WP_SITEURL', 'https://${DOMAIN}');
        define('FORCE_SSL_ADMIN', true);
    volumes:
      - ./data/wordpress/wp-content:/var/www/html/wp-content
      - ./data/wordpress/wp-config.php:/var/www/html/wp-config.php
    networks:
      - wp-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${PROJECT_NAME}-wp.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.${PROJECT_NAME}-wp.entrypoints=websecure"
      - "traefik.http.routers.${PROJECT_NAME}-wp.tls=true"
      - "traefik.http.routers.${PROJECT_NAME}-wp.tls.certfile=/certs/cert.pem"
      - "traefik.http.routers.${PROJECT_NAME}-wp.tls.keyfile=/certs/key.pem"
      - "traefik.http.services.${PROJECT_NAME}-wp.loadbalancer.server.port=80"

  db:
    image: mysql:8.0
    container_name: ${PROJECT_NAME}_db
    restart: unless-stopped
    env_file: .env
    environment:
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    volumes:
      - ./data/mysql:/var/lib/mysql
    networks:
      - wp-network
    command: --default-authentication-plugin=mysql_native_password

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: ${PROJECT_NAME}_pma
    restart: unless-stopped
    depends_on:
      - db
    environment:
      PMA_HOST: db
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    networks:
      - wp-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${PROJECT_NAME}-pma.rule=Host(`pma.${DOMAIN}`)"
      - "traefik.http.routers.${PROJECT_NAME}-pma.entrypoints=websecure"
      - "traefik.http.routers.${PROJECT_NAME}-pma.tls=true"
      - "traefik.http.routers.${PROJECT_NAME}-pma.tls.certfile=/certs/cert.pem"
      - "traefik.http.routers.${PROJECT_NAME}-pma.tls.keyfile=/certs/key.pem"
      - "traefik.http.services.${PROJECT_NAME}-pma.loadbalancer.server.port=80"

  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=wp-network"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
      - "--log.level=INFO"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "./certs:/certs:ro"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - wp-network

networks:
  wp-network:
    driver: bridge
EOL

# Archivo traefik.yml (configuración estática para solucionar problemas en WSL2)
cat > ~/projects/wordpress/template/traefik.yml <<'EOL'
http:
  routers:
    ${PROJECT_NAME}-wp:
      rule: "Host(\`${DOMAIN}\`)"
      entryPoints:
        - websecure
      service: ${PROJECT_NAME}-wp
      tls: {}
    
    ${PROJECT_NAME}-pma:
      rule: "Host(\`pma.${DOMAIN}\`)"
      entryPoints:
        - websecure
      service: ${PROJECT_NAME}-pma
      tls: {}

  services:
    ${PROJECT_NAME}-wp:
      loadBalancer:
        servers:
          - url: "http://${PROJECT_NAME}_wp:80"
    
    ${PROJECT_NAME}-pma:
      loadBalancer:
        servers:
          - url: "http://${PROJECT_NAME}_pma:80"

tls:
  stores:
    default:
      defaultCertificate:
        certFile: /certs/cert.pem
        keyFile: /certs/key.pem
EOL

# Archivo .env.example
cat > ~/projects/wordpress/template/.env.example <<'EOL'
# Project Settings
PROJECT_NAME=myproject
DOMAIN=myproject.test
ACME_EMAIL=your-real-email@example.com

# Database
DB_NAME=myproject_db
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
EOL

# Script para crear proyectos
cat > ~/projects/wordpress/template/scripts/create_wp_site.sh <<'EOL'
#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <project_name>"
  exit 1
fi

PROJECT_NAME=$1
BASE_DIR="$HOME/projects/wordpress"
TEMPLATE_DIR="$BASE_DIR/template"
PROJECT_DIR="$BASE_DIR/$PROJECT_NAME"

# Verificar si el directorio ya existe
if [ -d "$PROJECT_DIR" ]; then
  echo "Error: El directorio $PROJECT_DIR ya existe"
  exit 1
fi

# Verificar que existen los archivos fuente
if [ ! -f "$TEMPLATE_DIR/docker-compose.yml" ]; then
  echo "Error: No se encontró docker-compose.yml en $TEMPLATE_DIR"
  exit 1
fi

if [ ! -f "$TEMPLATE_DIR/.env.example" ]; then
  echo "Error: No se encontró .env.example en $TEMPLATE_DIR"
  exit 1
fi

# Crear estructura del proyecto
echo "Creando directorio del proyecto..."
mkdir -p "$PROJECT_DIR"/{data/{mysql,wordpress},letsencrypt,certs}

# Copiar archivos base
echo "Copiando archivos de configuración..."
cp "$TEMPLATE_DIR/docker-compose.yml" "$PROJECT_DIR/"
cp "$TEMPLATE_DIR/.env.example" "$PROJECT_DIR/.env"
if [ -f "$TEMPLATE_DIR/traefik.yml" ]; then
    cp "$TEMPLATE_DIR/traefik.yml" "$PROJECT_DIR/traefik.yml"
fi

# Configurar .env
echo "Configurando variables de entorno..."
sed -i "s/myproject/${PROJECT_NAME}/g" "$PROJECT_DIR"/.env
sed -i "s/myproject\.test/${PROJECT_NAME}.test/g" "$PROJECT_DIR"/.env
sed -i "s/your-real-email@example.com/your-email@${PROJECT_NAME}.test/g" "$PROJECT_DIR"/.env

# Generar tokens automáticamente para cada instalación
echo "🔐 Generando tokens de seguridad automáticamente..."

# Generar JWT Secret Key automáticamente
JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n' | tr -d '/')
sed -i "s|JWT_AUTH_SECRET_KEY=.*|JWT_AUTH_SECRET_KEY=${JWT_SECRET}|g" "$PROJECT_DIR"/.env

# Generar valores placeholder para reCAPTCHA (el usuario puede cambiarlos después)
RECAPTCHA_SITE_PLACEHOLDER="recaptcha-site-key-$(openssl rand -hex 16)"
RECAPTCHA_SECRET_PLACEHOLDER="recaptcha-secret-key-$(openssl rand -hex 16)"
sed -i "s|RECAPTCHA_SITE_KEY=.*|RECAPTCHA_SITE_KEY=${RECAPTCHA_SITE_PLACEHOLDER}|g" "$PROJECT_DIR"/.env
sed -i "s|RECAPTCHA_SECRET_KEY=.*|RECAPTCHA_SECRET_KEY=${RECAPTCHA_SECRET_PLACEHOLDER}|g" "$PROJECT_DIR"/.env

echo "✅ Tokens generados correctamente"

# Leer valores del .env recién creado
DB_NAME=$(grep 'DB_NAME=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
DB_USER=$(grep 'DB_USER=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
DB_PASSWORD=$(grep 'DB_PASSWORD=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
DOMAIN=$(grep 'DOMAIN=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
JWT_AUTH_SECRET_KEY=$(grep 'JWT_AUTH_SECRET_KEY=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
JWT_AUTH_CORS_ENABLE=$(grep 'JWT_AUTH_CORS_ENABLE=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
RECAPTCHA_SITE_KEY=$(grep 'RECAPTCHA_SITE_KEY=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
RECAPTCHA_SECRET_KEY=$(grep 'RECAPTCHA_SECRET_KEY=' "$PROJECT_DIR"/.env | cut -d '=' -f2)

# Generar Authentication Keys and Salts de WordPress
echo "Generando Authentication Keys and Salts de WordPress..."
WP_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/ 2>/dev/null || echo "")
if [ -z "$WP_KEYS" ]; then
    # Si no se puede obtener de la API, generar valores aleatorios
    WP_KEYS="define('AUTH_KEY',         '$(openssl rand -base64 48)');
define('SECURE_AUTH_KEY',  '$(openssl rand -base64 48)');
define('LOGGED_IN_KEY',    '$(openssl rand -base64 48)');
define('NONCE_KEY',        '$(openssl rand -base64 48)');
define('AUTH_SALT',        '$(openssl rand -base64 48)');
define('SECURE_AUTH_SALT', '$(openssl rand -base64 48)');
define('LOGGED_IN_SALT',   '$(openssl rand -base64 48)');
define('NONCE_SALT',       '$(openssl rand -base64 48)');"
fi

# Configurar traefik.yml si existe (después de leer DOMAIN)
if [ -f "$PROJECT_DIR/traefik.yml" ]; then
    echo "Configurando traefik.yml..."
    sed -i "s/\${PROJECT_NAME}/${PROJECT_NAME}/g" "$PROJECT_DIR"/traefik.yml
    sed -i "s/\${DOMAIN}/${DOMAIN}/g" "$PROJECT_DIR"/traefik.yml
fi

# Generar certificados SSL para el dominio específico
echo "Generando certificados SSL para ${DOMAIN}..."
openssl req -newkey rsa:2048 -nodes -keyout "$PROJECT_DIR/certs/key.pem" \
  -x509 -days 365 -out "$PROJECT_DIR/certs/cert.pem" \
  -subj "/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:pma.${DOMAIN},DNS:*.${DOMAIN},IP:127.0.0.1"

# Configurar hosts (solo en WSL)
if grep -q "WSL" /proc/version; then
  echo "🔧 Configurando archivo hosts en WSL..."
  echo "127.0.0.1 ${PROJECT_NAME}.test" | sudo tee -a /etc/hosts
  echo "127.0.0.1 pma.${PROJECT_NAME}.test" | sudo tee -a /etc/hosts
fi

# Crear wp-config.php inicial
echo "Creando wp-config.php..."
cat > "$PROJECT_DIR"/data/wordpress/wp-config.php <<EOF
<?php
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', 'db');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('WP_HOME', 'https://${DOMAIN}');
define('WP_SITEURL', 'https://${DOMAIN}');
define('FORCE_SSL_ADMIN', true);
\$_SERVER['HTTPS'] = 'on';

\$table_prefix = 'wp_';

/* Authentication Unique Keys and Salts */
${WP_KEYS}

/* JWT Authentication Configuration */
define('JWT_AUTH_SECRET_KEY', '${JWT_AUTH_SECRET_KEY}');
define('JWT_AUTH_CORS_ENABLE', ${JWT_AUTH_CORS_ENABLE});

/* Google reCAPTCHA V3 Configuration */
define('RECAPTCHA_SITE_KEY', '${RECAPTCHA_SITE_KEY}');
define('RECAPTCHA_SECRET_KEY', '${RECAPTCHA_SECRET_KEY}');

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
EOF

# Scripts de utilidad
echo "Creando scripts de control..."
cat > "$PROJECT_DIR"/start.sh <<EOF
#!/bin/bash
cd "$PROJECT_DIR"
docker-compose up -d
echo "✅ WordPress: https://${DOMAIN}"
echo "✅ phpMyAdmin: https://pma.${DOMAIN}"
EOF

cat > "$PROJECT_DIR"/stop.sh <<EOF
#!/bin/bash
cd "$PROJECT_DIR"
docker-compose down
EOF

# Configurar permisos
chmod +x "$PROJECT_DIR"/{start.sh,stop.sh}
chmod -R 755 "$PROJECT_DIR"/data/wordpress

echo "🎉 Sitio WordPress creado correctamente en: $PROJECT_DIR"
echo "🔹 Para iniciar: cd $PROJECT_DIR && ./start.sh"
echo "🔹 Para detener: cd $PROJECT_DIR && ./stop.sh"
EOL

# Configurar permisos
chmod +x ~/projects/wordpress/template/scripts/create_wp_site.sh

# Crear enlace simbólico
ln -sf ~/projects/wordpress/template/scripts/create_wp_site.sh ~/projects/wordpress/create_wp_site.sh
chmod +x ~/projects/wordpress/create_wp_site.sh

# 4. Generar certificado autofirmado inicial
openssl req -newkey rsa:2048 -nodes -keyout ~/projects/wordpress/template/certs/key.pem \
  -x509 -days 365 -out ~/projects/wordpress/template/certs/cert.pem \
  -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost"


echo "✅ Instalación completada!"
echo "📁 Los proyectos se crearán en: ~/projects/wordpress/"
echo "🔗 Esto está vinculado a tu carpeta de Windows para respaldo automático"
echo ""
echo "Ahora puedes crear nuevos sitios con:"
echo "  ~/projects/wordpress/create_wp_site.sh nombre-del-sitio"

