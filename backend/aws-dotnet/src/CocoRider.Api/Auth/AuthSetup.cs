using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Options;

namespace CocoRider.Api.Auth;

public sealed class AuthOptions
{
    /// <summary>"Cognito" in AWS; "Development" trusts X-Dev-* headers (local runs and tests only).</summary>
    public string Mode { get; set; } = "Cognito";

    public string Region { get; set; } = "";
    public string UserPoolId { get; set; } = "";

    /// <summary>App clients allowed to call the API (mobile app, admin dashboard).</summary>
    public List<string> ClientIds { get; set; } = [];
}

public static class Claims
{
    public const string Subject = "sub";
    public const string Phone = "phone_number";
    public const string PhoneVerified = "phone_number_verified";
    public const string Email = "email";
    public const string EmailVerified = "email_verified";
    public const string Groups = "cognito:groups";
    public const string AdminGroup = "admin";
    public const string AdminPolicy = "admin";
}

public static class AuthSetup
{
    public static IServiceCollection AddCocoRiderAuth(this IServiceCollection services, IConfiguration configuration, IHostEnvironment environment)
    {
        var options = configuration.GetSection("Auth").Get<AuthOptions>() ?? new AuthOptions();

        if (string.Equals(options.Mode, "Development", StringComparison.OrdinalIgnoreCase))
        {
            if (environment.IsProduction())
                throw new InvalidOperationException("Development authentication cannot be used in Production.");

            services.AddAuthentication(DevelopmentAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, DevelopmentAuthHandler>(DevelopmentAuthHandler.SchemeName, null);
        }
        else
        {
            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(jwt =>
            {
                jwt.Authority = $"https://cognito-idp.{options.Region}.amazonaws.com/{options.UserPoolId}";
                jwt.MapInboundClaims = false;

                // The app sends the Cognito ID token: it carries the verified phone number,
                // and its audience is the app client id.
                jwt.TokenValidationParameters.ValidAudiences = options.ClientIds;
                jwt.TokenValidationParameters.RoleClaimType = Claims.Groups;
                jwt.Events = new JwtBearerEvents
                {
                    OnTokenValidated = context =>
                    {
                        if (context.Principal?.FindFirst("token_use")?.Value != "id")
                            context.Fail("An ID token is required.");
                        return Task.CompletedTask;
                    },
                };
            });
        }

        services.AddAuthorizationBuilder()
            .SetFallbackPolicy(new Microsoft.AspNetCore.Authorization.AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build())
            .AddPolicy(Claims.AdminPolicy, policy => policy.RequireClaim(Claims.Groups, Claims.AdminGroup));

        services.AddScoped<CurrentUser>();
        return services;
    }
}

/// <summary>
/// Local development and tests: X-Dev-User is the Cognito sub, X-Dev-Phone the phone number
/// (phone sign-in) or X-Dev-Email the email address (email sign-in), X-Dev-Groups a comma
/// separated list of groups (e.g. "admin").
/// </summary>
public sealed class DevelopmentAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "Development";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var sub = Request.Headers["X-Dev-User"].ToString();
        if (string.IsNullOrEmpty(sub))
            return Task.FromResult(AuthenticateResult.NoResult());

        var claims = new List<Claim> { new(Claims.Subject, sub) };
        if (Request.Headers["X-Dev-Phone"].ToString() is { Length: > 0 } phone)
        {
            claims.Add(new Claim(Claims.Phone, phone));
            claims.Add(new Claim(Claims.PhoneVerified, "true"));
        }
        if (Request.Headers["X-Dev-Email"].ToString() is { Length: > 0 } email)
        {
            claims.Add(new Claim(Claims.Email, email));
            claims.Add(new Claim(Claims.EmailVerified, "true"));
        }
        foreach (var group in Request.Headers["X-Dev-Groups"].ToString().Split(',', StringSplitOptions.RemoveEmptyEntries))
            claims.Add(new Claim(Claims.Groups, group.Trim()));

        var identity = new ClaimsIdentity(claims, SchemeName, Claims.Subject, Claims.Groups);
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName)));
    }
}
