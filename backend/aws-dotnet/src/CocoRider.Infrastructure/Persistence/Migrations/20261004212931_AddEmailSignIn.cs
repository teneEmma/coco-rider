using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CocoRider.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddEmailSignIn : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "email",
                table: "users",
                type: "character varying(254)",
                maxLength: 254,
                nullable: true);

            // Every existing user signed in with an SMS code: their number is verified.
            migrationBuilder.AddColumn<bool>(
                name: "phone_verified",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.CreateIndex(
                name: "ix_users_email",
                table: "users",
                column: "email",
                unique: true,
                filter: "email IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_users_email",
                table: "users");

            migrationBuilder.DropColumn(
                name: "email",
                table: "users");

            migrationBuilder.DropColumn(
                name: "phone_verified",
                table: "users");
        }
    }
}
