using System.Text.Json.Serialization;
using CocoRider.Api.Auth;
using CocoRider.Api.Errors;
using CocoRider.Api.Features.Admin;
using CocoRider.Api.Features.Bookings;
using CocoRider.Api.Features.Documents;
using CocoRider.Api.Features.Profile;
using CocoRider.Api.Features.Reviews;
using CocoRider.Api.Features.Trips;
using CocoRider.Api.Features.Vehicles;
using CocoRider.Domain.Common;
using CocoRider.Domain.Verification;
using CocoRider.Infrastructure;
using CocoRider.Infrastructure.Persistence;
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

builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<DomainExceptionHandler>();
builder.Services.AddHealthChecks();

var app = builder.Build();

if (app.Configuration.GetValue<bool>("Database:MigrateOnStartup"))
{
    // A single container runs in the MVP, so migrating at startup is safe.
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<CocoRiderDbContext>().Database.MigrateAsync();
}

app.UseExceptionHandler();
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

app.Run();

/// <summary>Entry point reference for integration tests.</summary>
public partial class Program;
