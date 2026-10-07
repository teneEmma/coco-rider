using System.Globalization;
using System.Text;

namespace CocoRider.Domain.Verification;

/// <summary>
/// Cheap plausibility check on the text read from a document photo (OCR).
/// Cameroonian documents are bilingual, so each type lists French and English markers.
/// A match does not prove the document is genuine; it filters out blurry photos and wrong uploads
/// so that only doubtful documents reach the admin queue.
/// </summary>
public static class DocumentTextRules
{
    private static readonly Dictionary<DocumentType, string[]> Markers = new()
    {
        [DocumentType.NationalId] = ["CARTE NATIONALE", "NATIONAL IDENTITY", "IDENTITE", "IDENTITY CARD"],
        [DocumentType.DriverLicence] = ["PERMIS DE CONDUIRE", "DRIVING LICENCE", "DRIVING LICENSE", "DRIVING PERMIT"],
        [DocumentType.Insurance] = ["ASSURANCE", "INSURANCE", "ATTESTATION"],
        [DocumentType.VehicleRegistration] = ["CARTE GRISE", "IMMATRICULATION", "REGISTRATION"],
    };

    public static bool HasTextCheck(DocumentType type) => Markers.ContainsKey(type);

    public static bool LooksLike(DocumentType type, IEnumerable<string> detectedLines)
    {
        if (!Markers.TryGetValue(type, out var markers))
            return true;

        var text = Normalize(string.Join(' ', detectedLines));
        return markers.Any(m => text.Contains(m, StringComparison.Ordinal));
    }

    /// <summary>Upper-case, accents removed, whitespace collapsed ("Identité" → "IDENTITE").</summary>
    public static string Normalize(string value)
    {
        var decomposed = value.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);
        var previousWasSpace = false;

        foreach (var c in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark)
                continue;

            if (char.IsWhiteSpace(c))
            {
                if (!previousWasSpace)
                    builder.Append(' ');
                previousWasSpace = true;
                continue;
            }

            builder.Append(char.ToUpperInvariant(c));
            previousWasSpace = false;
        }

        return builder.ToString().Trim();
    }
}
