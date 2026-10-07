using CocoRider.Domain.Common;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CocoRider.Api.Errors;

/// <summary>
/// Turns domain errors into RFC 7807 problem responses. The "code" extension is stable
/// and is what the clients translate; "detail" is an English fallback.
/// </summary>
public sealed class DomainExceptionHandler(IProblemDetailsService problemDetails) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken ct)
    {
        (int status, string code, string detail)? problem = exception switch
        {
            NotFoundException e => (StatusCodes.Status404NotFound, e.Code, e.Message),
            ForbiddenException e => (StatusCodes.Status403Forbidden, e.Code, e.Message),
            DomainException e => (StatusCodes.Status409Conflict, e.Code, e.Message),
            DbUpdateConcurrencyException => (StatusCodes.Status409Conflict, "conflict.concurrent_update", "The resource was modified by someone else. Please retry."),
            DbUpdateException { InnerException: PostgresException { SqlState: PostgresErrorCodes.UniqueViolation } } =>
                (StatusCodes.Status409Conflict, "conflict.duplicate", "This resource already exists."),
            BadHttpRequestException e => (StatusCodes.Status400BadRequest, "request.invalid", e.Message),
            _ => null,
        };

        if (problem is not { } p)
            return false;

        context.Response.StatusCode = p.status;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = context,
            Exception = exception,
            ProblemDetails = new ProblemDetails
            {
                Status = p.status,
                Title = p.code,
                Detail = p.detail,
                Extensions = { ["code"] = p.code },
            },
        });
    }
}
