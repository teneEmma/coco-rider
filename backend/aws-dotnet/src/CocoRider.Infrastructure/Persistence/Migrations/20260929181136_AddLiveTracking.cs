using System;
using Microsoft.EntityFrameworkCore.Migrations;
using NetTopologySuite.Geometries;

#nullable disable

namespace CocoRider.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddLiveTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "trip_positions",
                columns: table => new
                {
                    trip_id = table.Column<Guid>(type: "uuid", nullable: false),
                    point = table.Column<Point>(type: "geography (point, 4326)", nullable: false),
                    heading_degrees = table.Column<double>(type: "double precision", nullable: true),
                    speed_kmh = table.Column<double>(type: "double precision", nullable: true),
                    recorded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    started_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_trip_positions", x => x.trip_id);
                    table.ForeignKey(
                        name: "fk_trip_positions_trips_trip_id",
                        column: x => x.trip_id,
                        principalTable: "trips",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "trip_shares",
                columns: table => new
                {
                    token = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    trip_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_by_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_trip_shares", x => x.token);
                    table.ForeignKey(
                        name: "fk_trip_shares_trips_trip_id",
                        column: x => x.trip_id,
                        principalTable: "trips",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_trip_shares_users_created_by_id",
                        column: x => x.created_by_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_trip_shares_created_by_id",
                table: "trip_shares",
                column: "created_by_id");

            migrationBuilder.CreateIndex(
                name: "ix_trip_shares_trip_id",
                table: "trip_shares",
                column: "trip_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "trip_positions");

            migrationBuilder.DropTable(
                name: "trip_shares");
        }
    }
}
