# Argos system data management

The [Argos](http://en.wikipedia.org/wiki/Argos_system) system has been used at the Norwegian Polar Institute since 1979.

This document outlines how Argos data is managed internally. Data management involves
* harvesting, archiving, processing, publishing, validating, and securing data
* monitoring and documenting the data flow, as well as systems, software, people and organisations involved

## System overview

Argos data is published in two main APIs
* [Tracking API](https://api.npolar.no/tracking/restricted/?q=) (**restricted**)
* [Buoy API](https://api.npolar.no/oceanography/buoy/?q=) (**open**)

Both are REST-style data services powered by [Npolar::Api::Json](https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/api/json.rb).

Several key data management aspects are defined in the [Service definition](http://api.npolar.no/service/tracking-arctic-fox-api): database, search engine, authorization rules, model,schema,accepted and outgoing formats.

Notice that the API has a separate CouchDB database, but share the Elasticsearch index ```tracking``` with other biological tracking data.

The platform metadata for Arctic foxes is maintained in the [Tracking Deployment API](http://api.npolar.no/tracking/deployment/?q=&filter-object=Arctic+fox)

Currently all transmitter platforms use the Argos system and all units are the same model: 
* Data provider: [CLS](http://cls.fr)
* Positioning technology: 
* Platform vendor: [Sirtrack](http://sirtrack.com)
* Platform model: [KiwiSat303](http://www.sirtrack.com/images/pdfs/303_K3HVHF.pdf)
* Sensor data [decoder](https://github.com/npolar/argos-ruby/blob/master/lib/argos/kiwisat303_decoder.rb)

## Data formats

Legacy Argos [DS]/[DIAG] files are converted to [Tracking JSON] using [argos-ascii](https://github.com/npolar/argos-ruby/wiki/argos-ascii) and published in a one time-operation (detailed below).

From 1 March 2014 all Argos data XML is downloaded nightly before being converted to JSON and published.

## Detailed data flow
The data pipeline consists of several steps:

**1. Harvesting.** Argos data XML for the last 20 days is [downloaded](https://github.com/npolar/argos-ruby/blob/master/lib/argos/download.rb) each night from CLS from their SOAP web service accesses via the [argos-soap](https://github.com/npolar/argos-ruby/wiki/argos-soap) commmand

**2. Archiving.** Data is archived on disk untouched in one file per platform per day

**3. Integrity check.** All files in the disk archive are fingerprinted and the number of messages is compared with the number of documents in the tracking API

**4. Preprocessing.** Any files not already in the API are converted to JSON using [XSLT](https://github.com/npolar/argos-ruby/blob/master/lib/argos/_xslt/argos-json.xslt)

**5. Publishing.** HTTP POST containing Array of JSON per platform per day

**6. Processing** (before persisting)

**7. Validation** (using the Tracking JSON schema)

**8. Storage** in CouchDB

**9. Search engine indexing** via Elasticsearch's river plugin (listens to CouchDB changes stream)  

Steps 1-5 occur client side, steps 6-8 occur in the Ruby model [Tracking](https://github.com/npolar/api.npolar.no/blob/master/lib/tracking.rb)#before_save, and step 9 occurs in Elasticsearch.

Step 7. A. Platform deployment metadata
The harvested data from CLS is merged with [platform metadata](https://github.com/npolar/api.npolar.no/wiki/Tracking-Deployment-API).

Pay special attention to the ```deployed``` time: Only messages with timestamp after deployed are marked with ```individual```, ```species```, and ```object``` information from the deployment API.

For reused platforms, the ```terminated``` time is critical to set for the first deployment, even if it's not known precisely. If there is no terminated time for the reused platform, it's impossible to know wether a given message is from the first or second deployment.

If the tracking deployment information changes, tracking data for the affected platforns needs to be republished to propogate the changes to each individual tracking document.

Step 7. B. Sensor data decoding
If sensor data is not already decoded, the [Kiwisat303Decoder](https://github.com/npolar/argos-ruby/blob/master/lib/argos/kiwisat303_decoder.rb) from [argos-ruby](https://github.com/npolar/argos-ruby) is used to extract four types of sensor messages.

### Future plans

A planned improvement to the publishing process is to trigger publishing when tracking platform deployment dates change.

Another planned improvment is data integrity checking via checksums and statistics beyond comparing document numbers.

## Disk archive

Original Argos DS/DIAG files: /mnt/datasets/Tracking/ARGOS/archive

Original Argos XML files: /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/*/program-11660/platform-*/argos*.xml

### JSON <- DS/DIAG
Legacy Argos DS/DIAG text files are converted to JSON using [argos-ruby](https://github.com/npolar/argos-ruby) and stored at /mnt/datasets/Tracking/ARGOS/seed/**/*.json 

### JSON <- Argos XML

Argos XML is converted to JSON using [XSLT] (), just prior to [publishing]

## Harvesting

Nighly cron job using [argos-soap](https://github.com/npolar/argos-ruby) --download

## Integrity check

[@todo]

## Publishing

Nightly cron job

## Security and authorization

Disk archive writes are reserved to staff at the Norwegian Polar Data Centre.
Access to tracking data is restricted, only the "external" user can create, update or delete data, while only principal investigators and data centre staff may at the moment access the data.
