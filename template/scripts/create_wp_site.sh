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
if [ -f "$TEMPLATE_DIR/traefik.yml" ]; then
    cp "$TEMPLATE_DIR/traefik.yml" "$PROJECT_DIR/traefik.yml"
fi

# Configurar .env
echo "Configurando variables de entorno..."
sed -i "s/myproject/${PROJECT_NAME}/g" "$PROJECT_DIR"/.env
sed -i "s/myproject\.test/${PROJECT_NAME}.test/g" "$PROJECT_DIR"/.env
sed -i "s/your-real-email@example.com/your-email@${PROJECT_NAME}.test/g" "$PROJECT_DIR"/.env

# Leer valores del .env recién creado
DB_NAME=$(grep 'DB_NAME=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
DB_USER=$(grep 'DB_USER=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
DB_PASSWORD=$(grep 'DB_PASSWORD=' "$PROJECT_DIR"/.env | cut -d '=' -f2)
DOMAIN=$(grep 'DOMAIN=' "$PROJECT_DIR"/.env | cut -d '=' -f2)

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
