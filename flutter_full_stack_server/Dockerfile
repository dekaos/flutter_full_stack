# Build from the project root with:
# docker build -f flutter_full_stack_server/Dockerfile .

# Build stage
# The Dart that CI's Flutter bundles: the server's SDK constraint is ^3.13.0,
# so an older image cannot even resolve the dependencies.
FROM dart:3.13.2 AS build

# Create a minimal workspace that preserves locked server dependency versions.
WORKDIR /app
COPY pubspec.lock .
COPY flutter_full_stack_server flutter_full_stack_server
RUN printf '%s\n' \
  'name: _' \
  'environment:' \
  '  sdk: ^3.8.0' \
  'workspace:' \
  '  - flutter_full_stack_server' \
  > pubspec.yaml
RUN dart pub get

# Compile the server. `dart build cli`, not `dart compile exe`: sqlite3, which
# Serverpod depends on, ships a native library through a build hook, and
# `compile exe` refuses any package with one. The bundle is the executable in
# bin/ and that library in lib/, which the executable finds relative to itself.
WORKDIR /app/flutter_full_stack_server
RUN dart build cli --target bin/main.dart --output build/cli

# Add a fallback for the copy of possibly missing directories.
RUN mkdir -p config web migrations

# Final stage
FROM alpine:latest
WORKDIR /app

# Environment variables
ENV runmode=production
ENV serverid=default
ENV logging=normal
ENV role=monolith

# The pronunciation language packs the app downloads, served at /models. They
# are not baked in - 355 MB a language - so mount the host's folder of them
# here: docker run -v /srv/language-packs:/app/models:ro ...
# See docs/pronunciation-models.md, "Serving and storage".
ENV MODELS_DIR=/app/models

# Copy runtime dependencies
COPY --from=build /runtime/ /

# Copy the compiled server: bin/main, and its native libraries in lib/
COPY --from=build /app/flutter_full_stack_server/build/cli/bundle/ ./

# Copy configuration files and resources
COPY --from=build /app/flutter_full_stack_server/config/ config/
COPY --from=build /app/flutter_full_stack_server/web/ web/
COPY --from=build /app/flutter_full_stack_server/migrations/ migrations/

# This file is required to enable the endpoint log filter in Insights.
COPY --from=build /app/flutter_full_stack_server/lib/src/generated/protocol.yaml lib/src/generated/protocol.yaml

# Expose ports
EXPOSE 8080
EXPOSE 8081
EXPOSE 8082

# Define the entrypoint command
ENTRYPOINT ./bin/main --mode=$runmode --server-id=$serverid --logging=$logging --role=$role
