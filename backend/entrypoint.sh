#!/bin/bash
set -e

echo "Running database migrations..."
dotnet ef database update \
    --project AuthApp.Persistence/AuthApp.Persistence.csproj \
    --startup-project AuthApp.Api/AuthApp.Api.csproj \
    -- --environment Production

echo "Starting API..."
dotnet AuthApp.Api.dll