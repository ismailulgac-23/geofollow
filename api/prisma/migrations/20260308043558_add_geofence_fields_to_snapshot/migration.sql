-- AlterTable
ALTER TABLE "location_snapshots" ADD COLUMN     "geofenceEvent" TEXT,
ADD COLUMN     "geofencePlaceName" TEXT,
ADD COLUMN     "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
