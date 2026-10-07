using CocoRider.Domain.Common;
using CocoRider.Domain.Users;
using CocoRider.Domain.Verification;
using static CocoRider.Tests.Domain.TestData;

namespace CocoRider.Tests.Domain;

public class VerificationTests
{
    private static readonly DateOnly Today = DateOnly.FromDateTime(Now.UtcDateTime);
    private static readonly VerificationRequirements Requirements = new();

    private static UserDocument Doc(DocumentType type, bool accepted = true, DateOnly? expiresOn = null)
    {
        var doc = new UserDocument(Guid.NewGuid(), type, $"key/{type}", "image/jpeg", Now);
        doc.Submit(expiresOn ?? (UserDocument.RequiresExpiryDate(type) ? Today.AddYears(1) : null), Today, Now);
        doc.ApplyAutomaticCheck(accepted, accepted ? null : "doubt", Now);
        return doc;
    }

    [Fact]
    public void Passenger_with_cni_and_selfie_is_verified_but_not_as_driver()
    {
        UserDocument[] docs = [Doc(DocumentType.NationalId), Doc(DocumentType.Selfie)];

        var passenger = VerificationRules.Evaluate(docs, Requirements.For(VerificationRole.Passenger), Today);
        var driver = VerificationRules.Evaluate(docs, Requirements.For(VerificationRole.Driver), Today);

        Assert.Equal(VerificationStatus.Verified, passenger.Status);
        Assert.Equal(VerificationStatus.Incomplete, driver.Status);
        Assert.Equal([DocumentType.DriverLicence, DocumentType.Insurance, DocumentType.VehicleRegistration], driver.Missing);
    }

    [Fact]
    public void Doubtful_document_goes_to_manual_review()
    {
        UserDocument[] docs = [Doc(DocumentType.NationalId), Doc(DocumentType.Selfie, accepted: false)];

        var outcome = VerificationRules.Evaluate(docs, Requirements.Passenger, Today);

        Assert.Equal(VerificationStatus.ManualReview, outcome.Status);
    }

    [Fact]
    public void Expired_insurance_makes_driver_incomplete()
    {
        var insurance = Doc(DocumentType.Insurance, expiresOn: Today.AddDays(10));
        UserDocument[] docs =
        [
            Doc(DocumentType.NationalId), Doc(DocumentType.Selfie), Doc(DocumentType.DriverLicence),
            insurance, Doc(DocumentType.VehicleRegistration),
        ];

        Assert.Equal(VerificationStatus.Verified, VerificationRules.Evaluate(docs, Requirements.Driver, Today).Status);

        var later = VerificationRules.Evaluate(docs, Requirements.Driver, Today.AddDays(11));
        Assert.Equal(VerificationStatus.Incomplete, later.Status);
        Assert.Equal([DocumentType.Insurance], later.Expired);
    }

    [Fact]
    public void Rejected_document_is_reported()
    {
        var selfie = Doc(DocumentType.Selfie, accepted: false);
        selfie.Reject("admin", "Photo floue", Now);

        var outcome = VerificationRules.Evaluate([Doc(DocumentType.NationalId), selfie], Requirements.Passenger, Today);

        Assert.Equal(VerificationStatus.Rejected, outcome.Status);
    }

    [Fact]
    public void Licence_requires_an_expiry_date()
    {
        var doc = new UserDocument(Guid.NewGuid(), DocumentType.DriverLicence, "k", "image/jpeg", Now);

        var error = Assert.Throws<DomainException>(() => doc.Submit(null, Today, Now));
        Assert.Equal("document.expiry_required", error.Code);
    }

    [Theory]
    [InlineData(DocumentType.NationalId, "RÉPUBLIQUE DU CAMEROUN", "Carte Nationale d'Identité", true)]
    [InlineData(DocumentType.NationalId, "REPUBLIC OF CAMEROON", "NATIONAL IDENTITY CARD", true)]
    [InlineData(DocumentType.DriverLicence, "Permis   de conduire", "", true)]
    [InlineData(DocumentType.VehicleRegistration, "Certificat d'immatriculation", "", true)]
    [InlineData(DocumentType.Insurance, "Facture", "Orange", false)]
    public void Document_text_markers(DocumentType type, string line1, string line2, bool expected) =>
        Assert.Equal(expected, DocumentTextRules.LooksLike(type, [line1, line2]));
}
