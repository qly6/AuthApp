FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Prevent NuGet from using Windows-specific fallback folders
ENV NUGET_FALLBACK_PACKAGES=

# Copy project files
COPY AuthApp.Api/AuthApp.Api.csproj AuthApp.Api/
COPY AuthApp.Application/AuthApp.Application.csproj AuthApp.Application/
COPY AuthApp.Domain/AuthApp.Domain.csproj AuthApp.Domain/
COPY AuthApp.Infrastructure/AuthApp.Infrastructure.csproj AuthApp.Infrastructure/
COPY AuthApp.Persistence/AuthApp.Persistence.csproj AuthApp.Persistence/

# Restore dependencies (first time)
RUN dotnet restore AuthApp.Api/AuthApp.Api.csproj

# Copy all source code
COPY . .

# Publish (allow implicit restore to handle any remaining dependencies)
WORKDIR /src/AuthApp.Api
RUN dotnet publish -c Release -o /app/publish

# Final runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final

WORKDIR /app
EXPOSE 8080
EXPOSE 8081

ENV ASPNETCORE_URLS=https://+:8081;http://+:8080
ENV ASPNETCORE_Kestrel__Certificates__Default__Password=password123
ENV ASPNETCORE_Kestrel__Certificates__Default__Path=/https/aspnetapp.pfx

COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "AuthApp.Api.dll"]