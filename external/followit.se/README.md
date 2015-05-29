# Svalbard reindeer GPS-tracking data management

This file contains behind-the-scenes documentation of the data management of Svalbard reindeer telemetry data.
* Data: [Svalbard reindeer tracking API](https://api.npolar.no/tracking/svalbard-reindeer/?q=) (**restricted**)
* [Platform deployment data](http://api.npolar.no/tracking/deployment/?q=&filter-provider=followit.se&object=Svalbard+reindeer)

More information
* Metadata: [Dataset](https://data.npolar.no/dataset/e62ec1a4-9aac-4a2f-9973-76d772c87f94) on [data.npolar.no](https://data.npolar.no/dataset/e62ec1a4-9aac-4a2f-9973-76d772c87f94)
* Data provider: [Followit](http://followit.se)
* [Data viewer](http://geo.followit.se/Pages/LoginPage.aspx) on [geo.followit.se](http://geo.followit.se)

## Archive
Original XML data stored under
* /mnt/datasets/Tracking/followit.se

## Harvesting
The archive is updated nightly with XML from the [GetUnitReportPositions](http://total.followit.se/DataAccess/TrackerService.asmx?op=GetUnitReportPositions) SOAP ([WSDL](http://total.followit.se/DataAccess/TrackerService.asmx?WSDL))
call.

Each night the last 28 days of data is collected from each tracker unit, stored as one XML file per day per tracker.
Data is validated prior to storage.
Data from previous days is only stored if the SHA-1 checksum differs from the existing version already on disk.


