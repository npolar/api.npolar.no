#  GPS tracking data management

This file contains behind-the-scenes documentation of the data management of Svalbard reindeer telemetry data.

* Data: [Svalbard reindeer tracking API](https://api.npolar.no/tracking/svalbard-reindeer/?q=) (**restricted**)
* Metadata: [Dataset](https://data.npolar.no/dataset/e62ec1a4-9aac-4a2f-9973-76d772c87f94) on [data.npolar.no](https://data.npolar.no/dataset/e62ec1a4-9aac-4a2f-9973-76d772c87f94)
* Data provider: [Followit](http://followit.se)
* [Data viewer](http://geo.followit.se/Pages/LoginPage.aspx) on [geo.followit.se](http://geo.followit.se)
* [Platform deployments](http://api.npolar.no/tracking/deployment/?q=&filter-vendor=Followit&object=Svalbard+reindeer)

## Archive
Original XML data stored under
* /mnt/datasets/Tracking/Followit

## Harvesting
The archive is updated nightly with XML from the [GetUnitReportPositions](http://total.followit.se/DataAccess/TrackerService.asmx?op=GetUnitReportPositions) SOAP ([WSDL](http://total.followit.se/DataAccess/TrackerService.asmx?WSDL))
call.

## SOAP examples

### Login (cookie)

```sh
curl --cookie-jar /tmp/followit-jar -XPOST -d@Login.xml http://total.followit.se/DataAccess/AuthenticationService.asmx -H "Content-Type: text/xml; charset=utf-8"
```        

### Get (tracker units)
```curl -XPOST -d@Get.xml http://total.followit.se/DataAccess/TrackerService.asmx -H "Content-Type: application/soap+xml; charset=utf-8" --cookie /tmp/followit-jar > trackers.xml```

### GetTrafficDates
```curl -XPOST -d@GetTrafficDates.xml http://total.followit.se/DataAccess/TrackerService.asmx -H "Content-Type: application/soap+xml; charset=utf-8" --cookie /tmp/followit-jar```

### GetUnitReportPositions
```curl -XPOST -d@GetUnitReportPositions.xml http://total.followit.se/DataAccess/TrackerService.asmx -H "Content-Type: application/soap+xml; charset=utf-8" --cookie /tmp/followit-jar > positions.xml```

### Logout
```sh
curl --cookie-jar /tmp/followit-jar -XPOST -d@soap/Logout.xml http://total.followit.se/DataAccess/AuthenticationService.asmx -H "Content-Type: text/xml; charset=utf-8"
```  
