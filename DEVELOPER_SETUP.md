# Developer Setup Guide

This guide is for the mobile app developer taking over the Aija & Abhi wedding platform. The Flutter app, website, API, admin dashboard, and PostgreSQL setup live in this repository.

## 1. Required software

Install these tools before cloning:

- Git
- Flutter SDK compatible with Dart `3.12.1` or newer in the same stable release line
- Android Studio with Android SDK 36 and platform tools
- JDK 17
- Node.js 22 LTS and npm
- Docker Desktop with Docker Compose

Run the following checks in PowerShell:

```powershell
git --version
flutter doctor -v
java -version
node --version
npm --version
docker --version
docker compose version
```

Resolve every Android-related error reported by `flutter doctor -v` before continuing. Accept Android licenses when requested:

```powershell
flutter doctor --android-licenses
```

## 2. Clone and install dependencies

```powershell
git clone https://github.com/muhammadzawarshah/wedding-app-and-website.git
cd wedding-app-and-website
flutter pub get
npm install
```

Do not run `flutter create .` because the Android/iOS configuration and app assets already exist.

## 3. Configure the local backend

Create local environment files from the committed examples:

```powershell
Copy-Item apps\api\.env.example apps\api\.env
Copy-Item apps\web\.env.example apps\web\.env.local
```

Change `JWT_SECRET` in `apps/api/.env` to a long random development value. Never commit the real `.env` files.

Start PostgreSQL:

```powershell
docker compose up -d postgres
docker compose ps
```

The local database defaults are:

- Host: `localhost`
- Port: `5432`
- Database: `wedding`
- User: `wedding`
- Password: `wedding`

Development mode creates/updates tables through TypeORM. Production must use migrations rather than schema synchronization.

## 4. Run API and website

Open two PowerShell terminals from the repository root.

Terminal 1:

```powershell
npm run dev:api
```

Terminal 2:

```powershell
npm run dev:web
```

Local services:

- Website: `http://localhost:3000`
- Admin dashboard: `http://localhost:3000/admin`
- API: `http://localhost:4000/api`

The supplied `START-SERVERS.bat` contains the original machine's absolute path. Prefer the commands above after cloning to another location.

## 5. Run the Flutter app

### Android emulator

Start an Android emulator from Android Studio, then run:

```powershell
flutter devices
flutter run
```

The default API URL is `http://10.0.2.2:4000/api`, which points from the Android emulator to the host computer.

### Physical Android phone with local API

1. Connect the computer and phone to the same Wi-Fi network.
2. Find the computer's IPv4 address using `ipconfig`.
3. Allow TCP port `4000` through Windows Firewall when prompted.
4. Run the app with the computer's LAN address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:4000/api
```

Replace `192.168.x.x` with the computer's real IPv4 address. Do not use `localhost` or `10.0.2.2` on a physical phone.

The app also has server settings backed by `shared_preferences`, so the API address can be changed at runtime without rebuilding.

### Production API

```powershell
flutter run --dart-define=API_BASE_URL=https://abhiaijawedding.co.uk/backend-api/api
```

## 6. Access codes

Development currently includes these seeded four-digit codes:

| Code | Role |
| --- | --- |
| `1234` | Guest |
| `9001` | Wedding organizer |
| `1001` | Aija, super admin |
| `1002` | Abhi, super admin |

The guest code must not open the admin dashboard.

## 7. Build and quality checks

Run these before opening a pull request:

```powershell
flutter analyze
flutter test
npm run build
```

Build an Android APK against the production backend:

```powershell
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://abhiaijawedding.co.uk/backend-api/api
```

APK output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

The current Android release configuration uses the debug signing key. Configure a private release keystore before publishing to Google Play; never commit the keystore or its passwords.

## 8. Architecture notes

- Flutter API configuration: `lib/config/app_config.dart`
- Flutter screens: `lib/screens/`
- Website: `apps/web/src/`
- Backend modules: `apps/api/src/modules/`
- Database entities: `apps/api/src/database/entities/`
- Uploaded development media: `uploads/` (ignored by Git)
- Public website media: `apps/web/public/images/`
- Flutter media: `assets/images/`

The Flutter app uses fallback content when the API is unavailable. Check the app's online/offline indicator before assuming backend data loaded successfully.

## 9. Common setup problems

### API cannot connect to PostgreSQL

```powershell
docker compose ps
docker compose logs postgres
```

Confirm port `5432` is free and `DATABASE_URL` matches `apps/api/.env`.

### Phone cannot reach the local API

- Use the computer's LAN IPv4 address.
- Keep phone and computer on the same network.
- Confirm `http://COMPUTER_IP:4000/api/wedding` opens from the phone browser.
- Check Windows Firewall and guest/client isolation on Wi-Fi.

### Gradle or Android build fails

```powershell
flutter clean
flutter pub get
flutter doctor -v
cd android
.\gradlew.bat --stop
cd ..
flutter run
```

Confirm Android SDK 36 and JDK 17 are selected. Do not manually downgrade Gradle, Kotlin, or Android Gradle Plugin versions without testing the complete app.

### Website cannot reach API

Confirm both servers are running and `apps/web/.env.local` contains:

```env
NEXT_PUBLIC_API_URL=http://localhost:4000/api
```

Restart the Next.js server after changing `.env.local`.

## 10. Handover rules

- Create a feature branch before changes.
- Keep Flutter, website, and API contracts aligned.
- Do not commit generated builds, local `.env` files, database data, uploads, signing keys, or VPS credentials.
- Do not replace the existing visual identity, assets, access flow, or API structure without approval.
- Verify mobile behavior on both an emulator and a physical Android phone.

## 11. Current verification status

- `flutter analyze`: passes with no issues.
- API and website production builds: pass.
- `test/widget_test.dart`: currently fails because the test expects the old splash text `PASSPORT`; the current splash implementation no longer exposes that text at the tested moment. Treat this as a stale test expectation, not a setup failure. Review the intended splash behavior with the project owner before updating the test or application.
