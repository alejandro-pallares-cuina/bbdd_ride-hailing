# Arranque MySQL + Grafana y carga de datos de prueba

## Requisitos
- Docker + Docker Compose
- Puertos libres:
  - 3307 (MySQL)
  - 3000 (Grafana)

---

## 1. Arrancar la base de datos y el dashboard

Levanta todo con Docker Compose (bbdd, dashboard y carga de datos):

```bash
docker compose up -d
```

## 2.Ver el Dashboard
### 1. Abre Grafana en el navegador:
- http://localhost:3000

### 2. Inicia sesión con el usuario/contraseña configurados en tu compose.yml o .env.

### 3. Encontrar los dashboards:
- En el menú izquierdo → Dashboards
- Deberías ver una carpeta (por ejemplo “Ride‑Hailing”) con dashboards como:

    - Ride‑Hailing — Negocio
    - Ride‑Hailing — Salud MySQL

### EXTRA. Si no aparecen dashboards:

```bash

docker compose restart grafana

docker logs movilidad-grafana --tail 200
```