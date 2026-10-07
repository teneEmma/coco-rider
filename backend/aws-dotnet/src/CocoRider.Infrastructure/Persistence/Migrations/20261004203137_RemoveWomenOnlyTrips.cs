using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CocoRider.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RemoveWomenOnlyTrips : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "women_only",
                table: "trips");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "women_only",
                table: "trips",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }
    }
}
