FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src

COPY . .

# DEBUG (temporary)
RUN ls -la

# MUST SHOW backend folder here
RUN dotnet restore backend/AuthApp.sln

RUN dotnet publish backend/AuthApp.Api/AuthApp.Api.csproj \
    -c Release \
    -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0

WORKDIR /app

COPY --from=build /app/publish .

EXPOSE 8080
EXPOSE 8443

ENV ASPNETCORE_URLS="https://+:8443;http://+:8080"

ENTRYPOINT ["dotnet", "AuthApp.Api.dll"]