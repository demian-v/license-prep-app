# Stage 1: Build the Flutter web app
FROM cirrusci/flutter:3.24.3 AS build-env

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
RUN flutter build web --release --web-renderer html

# Stage 2: Create the runtime image with nginx
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the built web app from the build stage
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port 8080 (Cloud Run requirement)
EXPOSE 8080

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
