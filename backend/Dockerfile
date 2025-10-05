# Stage 1: Builder
FROM dart:stable AS builder

WORKDIR /app

# Copy pubspec files and get dependencies
COPY . .

# Get dependencies
RUN dart pub get

# Ensure the template directory exists for compilation
RUN mkdir -p lib/templates

# Compile the server
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Runner
# Use a minimal base image for the final executable
FROM debian:stable-slim AS runner

# Install ca-certificates for HTTPS connections
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled executable from the builder stage
COPY --from=builder /app/bin/server bin/server

# Copy runtime assets (like HTML templates)
COPY --from=builder /app/lib/templates lib/templates

# Expose the port the app runs on
EXPOSE 8080

# Run the server
CMD ["/app/bin/server"]


