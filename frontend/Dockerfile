FROM ghcr.io/cirruslabs/flutter:stable AS builder

ARG API_URL=http://localhost:8500
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release \
    --dart-define=API_URL=${API_URL}

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
