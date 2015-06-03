# Svalbard reindeer GPS-tracking data management

This file contains behind-the-scenes documentation of the data management of Svalbard reindeer telemetry data.
* Data: [Svalbard reindeer tracking API](https://api.npolar.no/tracking/svalbard-reindeer/?q=) (**restricted**)
* [Platform deployment data](http://api.npolar.no/tracking/deployment/?q=&filter-provider=followit.se&object=Svalbard+reindeer)

See [Svalbard reindeer tracking API](https://github.com/npolar/api.npolar.no/wiki/Svalbard-reindeer-tracking-API) for how to retrieve the data.

More information
* Metadata: [Dataset](https://data.npolar.no/dataset/e62ec1a4-9aac-4a2f-9973-76d772c87f94) on [data.npolar.no](https://data.npolar.no/dataset/e62ec1a4-9aac-4a2f-9973-76d772c87f94)
* Data provider: [Followit](http://followit.se)
* [Data viewer](http://geo.followit.se/Pages/LoginPage.aspx) on [geo.followit.se](http://geo.followit.se)

## Archive
Original XML data stored under
* /mnt/datasets/Tracking/followit.se

## Harvesting
The archive is updated with XML from the [GetUnitReportPositions](http://total.followit.se/DataAccess/TrackerService.asmx?op=GetUnitReportPositions) SOAP ([WSDL](http://total.followit.se/DataAccess/TrackerService.asmx?WSDL))
call, see [Followit::TrackerService](https://github.com/npolar/api.npolar.no/blob/master/external/followit.se/ruby/lib/followit/tracker_service.rb).

Data is organised in 1 file per tracker unit per month, example:
* 2015/2015-05/followit-2015-05-tracker-11548.xml

Existing files are only updated if the new SHA-1 checksum differs from the existing version, and the number of positions differ (needed since internal Followit data changes).