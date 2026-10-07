# Builds the API image. Fargate runs it on ARM (Graviton), about 20% cheaper than x86:
#   docker buildx build --platform linux/arm64 -t coco-rider-api .
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG TARGETARCH
WORKDIR /src

COPY CocoRider.slnx ./
COPY src/CocoRider.Domain/CocoRider.Domain.csproj src/CocoRider.Domain/
COPY src/CocoRider.Infrastructure/CocoRider.Infrastructure.csproj src/CocoRider.Infrastructure/
COPY src/CocoRider.Api/CocoRider.Api.csproj src/CocoRider.Api/
RUN dotnet restore src/CocoRider.Api/CocoRider.Api.csproj -a $TARGETARCH

COPY src/ src/
RUN dotnet publish src/CocoRider.Api/CocoRider.Api.csproj -c Release -a $TARGETARCH --no-restore -o /app

# Chiseled image: no shell or package manager, runs as a non-root user.
FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "CocoRider.Api.dll"]
