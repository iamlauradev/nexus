# Nexus — Media Tracker

App de seguimiento personal para manga, anime, doramas, películas y series.
Estética RPG oscura (dorado/morado/negro). Multi-usuario con listas privadas.

## Stack
- **Backend**: FastAPI (Python) — puerto 8500
- **Frontend web**: Flutter → Nginx — puerto 3500
- **DB**: PostgreSQL 16 — puerto 5433 (interno)
- **APK Android**: mismo código Flutter, compilado con `build_apk.sh`

---

## Arrancar

```bash
cd /opt/docker/nexus

# Primera vez (construye las imágenes — Flutter tarda ~15 min):
docker compose up -d

# Importar Excel histórico (solo una vez):
DB_HOST=localhost DB_PORT=5433 python3 import/excel_import.py \
  --excel "/opt/docker/zonatmo/Doramas, manga y anime.xlsx" \
  --user laura
```

La app web queda disponible en **http://localhost:3500**  
La API docs en **http://localhost:8500/docs**

---

## Primer acceso

Usuario creado por el import: `laura` / contraseña inicial: `changeme`  
Cámbiala desde el perfil o con:
```sql
-- conectar a nexusdb (puerto 5433)
-- El hash se regenera al hacer login con la nueva contraseña desde la app
```

Para crear usuarios adicionales: ir a la pantalla de login → "¿Sin cuenta? Regístrate".

---

## Construir APK Android

```bash
# Editar .env: API_EXTERNAL_URL=http://TU_IP_SERVIDOR:8500
./build_apk.sh
# APK en: frontend/build/app/outputs/flutter-apk/app-release.apk
```

---

## Sistema de valoración (colores del Excel → app)

| Color Excel | Categoría app   |
|-------------|-----------------|
| Morado      | ★ Must          |
| Teal/verde azul | ♥ Me encanta |
| Amarillo-dorado | ✦ Es muy bonita |
| Verde       | ◆ Es bonita     |
| Naranja     | ◆ Es bonita (equiv) |
| Salmón      | ◇ Pasable       |
| Rojo        | ✕ No me ha gustado |
| Gris        | — Abandonado    |

---

## Estructura de archivos

```
nexus/
├── backend/          # API FastAPI
├── frontend/         # App Flutter
│   └── lib/
│       ├── screens/  # Pantallas
│       ├── theme/    # Tema RPG
│       └── services/ # API client
├── sql/              # Schema PostgreSQL
├── import/           # Importador Excel
├── build_apk.sh      # Genera APK Android
└── docker-compose.yml
```

---

## Añadir TMDB para películas/series/doramas (opcional)

1. Crear cuenta en https://www.themoviedb.org/
2. API → generar API Key (gratuita)
3. Añadir al .env: `TMDB_API_KEY=tu_clave`
4. `docker compose restart nexus_backend`

Sin TMDB, la búsqueda de metadatos para películas/series usa solo los datos del Excel importado.  
AniList (manga/anime) funciona sin API key.
