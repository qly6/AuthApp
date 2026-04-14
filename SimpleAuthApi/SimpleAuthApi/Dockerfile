# Sử dụng SDK để build ứng dụng
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy file project và restore dependencies
COPY ["SimpleAuthApi.csproj", "."]
RUN dotnet restore "./SimpleAuthApi.csproj"

# Copy toàn bộ source code và build
COPY . .
RUN dotnet publish "./SimpleAuthApi.csproj" -c Release -o /app/publish

# Sử dụng runtime image để chạy ứng dụng
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 80
EXPOSE 443

# Copy build output từ stage trước
COPY --from=build /app/publish .

# Đặt biến môi trường mặc định
ENV ASPNETCORE_URLS=http://+:80

# Entry point
ENTRYPOINT ["dotnet", "SimpleAuthApi.dll"]