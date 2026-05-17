#!/bin/bash
# Builds the Android APK inside Docker.
# The APK ends up at: ./frontend/build/app/outputs/flutter-apk/app-release.apk
set -e

echo "=== Nexus APK Builder ==="
echo "Construyendo APK con Flutter Docker..."

docker run --rm \
  -v "$(pwd)/frontend":/app \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "
    flutter pub get && \
    flutter build apk --release \
      --dart-define=API_URL=\${API_URL:-http://tu-servidor:8500} && \
    echo '✓ APK generado en build/app/outputs/flutter-apk/app-release.apk'
  "

echo ""
echo "APK disponible en: frontend/build/app/outputs/flutter-apk/app-release.apk"
echo "Cópialo a tu Android o compártelo."
