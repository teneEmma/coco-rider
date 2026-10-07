using CocoRider.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CocoRider.Api.Features;

public static class Concurrency
{
    /// <summary>
    /// Runs an operation that changes a trip's seat count. If another request changed the same trip
    /// in the meantime (xmin mismatch), the tracked state is discarded and the whole operation is
    /// replayed on fresh data, so the business rules are re-checked against the new seat count.
    /// </summary>
    public static async Task<T> RetryAsync<T>(CocoRiderDbContext db, Func<Task<T>> operation, int attempts = 3)
    {
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                return await operation();
            }
            catch (DbUpdateConcurrencyException) when (attempt < attempts)
            {
                db.ChangeTracker.Clear();
            }
        }
    }
}
