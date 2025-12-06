# Changelog

## [1.1.0] - 2025-12-06

### ✨ Nuevas Características
- Agregada configuración estática de Traefik (`traefik.yml`) para solucionar problemas de conexión en WSL2
- Configuración híbrida de Traefik (Docker provider + File provider) para mayor confiabilidad
- Generación automática de certificados SSL con Subject Alternative Names (SAN) para cada proyecto
- Redirección automática HTTP → HTTPS configurada en Traefik

### 🐛 Correcciones
- Solucionado error 404 al acceder a sitios WordPress en WSL2
- Corregida configuración de certificados SSL (ahora usa certificados estáticos en lugar de ACME para dominios locales)
- Mejorada la configuración de red de Traefik para mejor descubrimiento de servicios

### 📝 Mejoras
- Documentación completa actualizada con sección de troubleshooting
- Scripts actualizados para incluir configuración de `traefik.yml`
- `.gitignore` mejorado para excluir archivos sensibles y datos de proyectos
- Cambio de ubicación de proyectos a `~/projects/wordpress/` para respaldo automático en Windows

### 🔧 Cambios Técnicos
- Actualizado `docker-compose.yml` para usar provider de archivos de Traefik
- Agregado `extra_hosts` a Traefik para mejor compatibilidad con WSL2
- Certificados SSL ahora se generan con SAN incluyendo dominio principal, subdominios y localhost

## [1.0.0] - Versión Inicial

### Características Iniciales
- Scripts de instalación y creación de proyectos WordPress
- Configuración Docker Compose con WordPress, MySQL, phpMyAdmin y Traefik
- Generación automática de certificados SSL autofirmados
- Configuración automática de hosts en WSL

