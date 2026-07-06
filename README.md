# Aija & Abhi Wedding Platform

One repository containing:

- Flutter mobile application
- Next.js website and admin dashboard
- NestJS REST API
- PostgreSQL database configuration

The project is close to final. Start with [DEVELOPER_SETUP.md](DEVELOPER_SETUP.md) before making changes.

## Main folders

| Path | Purpose |
| --- | --- |
| `lib/` | Flutter application source |
| `assets/` | Flutter images and media |
| `apps/web/` | Next.js website and admin dashboard |
| `apps/api/` | NestJS backend API |
| `streaming/` | Streaming-related project files |
| `docker-compose.yml` | Local PostgreSQL database |

## Quick verification

```powershell
npm install
flutter pub get
npm run build
flutter analyze
flutter test
```

Do not commit `.env` files, signing keys, database dumps, uploaded guest media, or generated build folders.
