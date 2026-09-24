using System.Text.Json.Serialization;
using CocoRider.Api.Auth;
using CocoRider.Api.Errors;
using CocoRider.Api.Features.Admin;
using CocoRider.Api.Features.Bookings;
using CocoRider.Api.Features.Documents;
using CocoRider.Api.Features.Messaging;
using CocoRider.Api.Features.Notifications;
using CocoRider.Api.Features.Profile;
using CocoRider.Api.Features.Reviews;
using CocoRider.Api.Features.Trips;
using CocoRider.Api.Features.Vehicles;
using CocoRider.Domain.Common;
using CocoRider.Domain.Verification;
using CocoRider.Infrastructure;
using CocoRider.Infrastructure.Persistence;
using CocoRider.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<PlatformPolicy>(builder.Configuration.GetSection("Policy"));
builder.Services.Configure<VerificationRequirements>(builder.Configuration.GetSection("Verification"));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddHttpContextAccessor();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddCocoRiderAuth(builder.Configuration, builder.Environment);
builder.Services.AddScoped<VerificationService>();
builder.Services.AddScoped<TripReader>();
builder.Services.Configure<LifecycleOptions>(builder.Configuration.GetSection("Lifecycle"));
builder.Services.AddScoped<TripLifecycle>();
builder.Services.AddHostedService<TripLifecycleService>();
builder.Services.AddSingleton<NotificationQueue>();
builder.Services.AddSingleton<Notifier>();
builder.Services.AddHostedService<NotificationDispatcher>();

builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<DomainExceptionHandler>();
builder.Services.AddHealthChecks();
builder.Services.AddCors();

var app = builder.Build();

if (app.Configuration.GetValue<bool>("Database:MigrateOnStartup"))
{
    // A single container runs in the MVP, so migrating at startup is safe.
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<CocoRiderDbContext>().Database.MigrateAsync();
}

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    // Lets the Flutter web build call a local API. In AWS, CORS is handled by API Gateway.
    app.UseCors(cors => cors.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
}

app.UseStatusCodePages();
app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/health").AllowAnonymous();
app.MapProfileEndpoints();
app.MapDocumentEndpoints();
app.MapVehicleEndpoints();
app.MapTripEndpoints();
app.MapBookingEndpoints();
app.MapReviewEndpoints();
app.MapAdminEndpoints();
app.MapDeviceEndpoints();
app.MapMessageEndpoints();

if (app.Environment.IsDevelopment() && app.Services.GetService<FakeDocumentStorage>() is { } fakeStorage)
{
    // Stand-in for the pre-signed S3 URLs when running locally without AWS.
    app.MapPut("/dev/uploads/{**key}", async (string key, HttpRequest request) =>
    {
        using var buffer = new MemoryStream();
        await request.Body.CopyToAsync(buffer);
        fakeStorage.Put(key, buffer.ToArray(), request.ContentType ?? "application/octet-stream");
        return Results.Ok();
    }).AllowAnonymous();
    app.MapGet("/dev/uploads/{**key}", (string key) => fakeStorage.Get(key) is { } stored
        ? Results.File(stored.Bytes, stored.ContentType)
        : Results.NotFound()).AllowAnonymous();
}

app.Run();

/// <summary>Entry point reference for integration tests.</summary>
public partial class Program;
