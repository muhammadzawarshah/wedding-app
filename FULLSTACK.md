# Aija & Abhi Wedding Platform

## Structure

- `apps/web`: Next.js 16 App Router website and admin dashboard.
- `apps/api`: NestJS 11 modular REST API.
- `docker-compose.yml`: PostgreSQL 17 development database.
- Flutter app (root `lib/`): the mobile client, now wired to the same `apps/api`
  backend as the website and admin dashboard.

## API modules

- `auth`: four-digit guest/admin code login and JWT creation.
- `wedding`: wedding config, itinerary, family, and approved gallery.
- `uploads`: guest memory submissions and moderation.
- `chatbot`: FAQ matching and organizer handoff queue.
- `admin`: dashboard statistics for organizers and super admins.

## Development

```powershell
npm install
docker compose up -d postgres
Copy-Item apps\api\.env.example apps\api\.env
Copy-Item apps\web\.env.example apps\web\.env.local
npm run dev:api
npm run dev:web
```

- Website: `http://localhost:3000`
- API: `http://localhost:4000/api`
- Admin dashboard: `http://localhost:3000/admin`

## Flutter mobile app (shared backend)

The Flutter app talks to the same API. The base URL is configurable via
`--dart-define` (see `lib/config/app_config.dart`); it defaults to
`http://10.0.2.2:4000/api` (the Android emulator alias for the host machine).

```powershell
npm run dev:api                 # start the backend first
flutter run                     # Android emulator, uses the 10.0.2.2 default
# Physical device / other host:
flutter run --dart-define=API_BASE_URL=http://<your-host-ip>:4000/api
# Release build against production:
flutter build apk --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

What is wired to the backend (each with graceful fallback to bundled mock data
when the server is unreachable, so the APK still opens offline):

- Login (`POST /auth/code-login`): real JWT + role-based routing.
- Itinerary, Family, Gallery (`GET /wedding/*`): live content.
- Upload Memories (`POST /uploads`): lands in the shared moderation queue.
- AI Assistant (`POST /chatbot/ask`): shared FAQ; unanswered questions go to the
  same organizer handoff queue as the website.

Android cleartext HTTP is allowed only for local dev hosts via
`android/app/src/main/res/xml/network_security_config.xml`; production must use
HTTPS. Full multipart photo/video upload (`POST /admin/media`) can be layered on
top of the current metadata submission.

## Production checks

```powershell
npm run build -w @wedding/api
npm run build -w @wedding/web
```

Do not use TypeORM `synchronize` in production. Add migrations and object storage before live guest media uploads.
