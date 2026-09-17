# Stage 1: Build the Flutter web app
#
# Risk #49 — both base images were unpinned (`flutter:latest`, `nginx:alpine`),
# so two builds of the same commit could produce different artefacts and a
# Flutter release could change the web build without a single line changing
# here. Pinned to the version this repo is developed against; bump it
# deliberately, together with a local `flutter build web --release`.
FROM ghcr.io/cirruslabs/flutter:3.41.7 AS build-env

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get Flutter dependencies
RUN flutter pub get

# Copy the rest of the source code
COPY . .

# Enable web support and build for web
RUN flutter config --enable-web
RUN flutter build web --release

# Stage 2: Create the runtime image with nginx
# Pinned for the same reason as the build stage (risk #49).
FROM nginx:1.27-alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the built web app from the build stage
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port 8080 (Cloud Run requirement)
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
