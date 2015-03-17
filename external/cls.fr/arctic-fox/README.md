# Arctic fox tracking data management

This file contains behind-the-scenes documentation of the data management of Arctic fox telemetry data.

Data management involves
* harvesting, archiving, processing, publishing, validating, and securing data
* monitoring and documenting the data flow, as well as systems, software, people and organisations involved

For metadata, including information on accessing and citing the dataset, as well as people and organisations involved, visit [data.npolor.no](https://data.npolar.no/dataset/8337bbf0-85e9-49cb-b070-9fa5fe503c82).

For detailed documentation of how to access the data, visit the [Tracking Arctic fox API wiki](https://github.com/npolar/api.npolar.no/wiki/Tracking-Arctic-fox-API).

## System overview

Data is published in the [Arctic fox tracking API](https://api.npolar.no/tracking/arctic-fox/?q=) (**restricted**), a REST-style data service, powered by [Npolar::Api::Json](https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/api/json.rb).

Several key data management aspects are defined in the [Service definition](http://api.npolar.no/service/tracking-arctic-fox-api): database, search engine, authorization rules. 
Notice that the API has a separate CouchDB database, but share the Elasticsearch index ```tracking``` with other biological tracking data.

The platform metadata for Arctic foxes is maintained in the [Tracking Deployment API](http://api.npolar.no/tracking/deployment/?q=&filter-object=Arctic+fox)

Currently all transmitter platforms use the Argos system and all units are the same model: 
* Data provider: [CLS](http://cls.fr)
* Positioning technology: [Argos](http://en.wikipedia.org/wiki/Argos_system) system
* Platform vendor: [Sirtrack](http://sirtrack.com)
* Platform model: [KiwiSat303](http://www.sirtrack.com/images/pdfs/303_K3HVHF.pdf)
* Sensor data [decoder](https://github.com/npolar/argos-ruby/blob/master/lib/argos/kiwisat303_decoder.rb)
* 
## Data formats

Legacy Argos [DS]/[DIAG] files are converted to [Tracking JSON] using [argos-ascii](https://github.com/npolar/argos-ruby/wiki/argos-ascii) and published in a one time-operation (detailed below).

From 1 March 2014 all Argos data XML is downloaded nightly before being converted to JSON and published.

## Detailed data flow
The data pipeline consists of several steps:

**- Harvesting.** Argos data XML for the last 20 days is [downloaded](https://github.com/npolar/argos-ruby/blob/master/lib/argos/download.rb) each night from CLS from their SOAP web service accesses via the [argos-soap](https://github.com/npolar/argos-ruby/wiki/argos-soap) commmand
**- Archiving.** Data is archived on disk untouched in one file per platform per day
**- Integrity check.** All files in the disk archive are fingerprinted and the number of messages is compared with the number of documents in the tracking API
**- Preprocessing. Any files not already in the API are converted to JSON using [XSLT](https://github.com/npolar/argos-ruby/blob/master/lib/argos/_xslt/argos-json.xslt)
**- Publishing.** HTTP POST containing Array of JSON per platform per day
**- Processing** (before persisting)
**- Validation** (using the Tracking JSON schema)
**- Storage** in CouchDB
**- Search engine indexing** via Elasticsearch's river plugin (listens to CouchDB changes stream)  

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

### Disk archive

Original Argos DS/DIAG files: /mnt/datasets/Tracking/ARGOS/archive

Original Argos XML files: /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/*/program-11660/platform-*/argos*.xml

#### JSON <- DS/DIAGKiwiSat303
Legacy Argos DS/DIAG text files are converted to JSON using [argos-ruby](https://github.com/npolar/argos-ruby) and stored at /mnt/datasets/Tracking/ARGOS/arctic-fox/**/*.json 

For each of the years 2012, 2013, and 2014:
```sh
[external@gustav ~]$ YEAR=2012 && ~/argos-ruby/bin/argos-ascii --debug --filter='lambda {|d| ["113907","113908",
"113908","113909","113909","113910","113911","113912","113913","113913",
"113914","113915","131424","131425","131426","131427","131428"].include? d[:platform].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR```

http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2012-01-01..2013-01-01
I, [2015-03-12T10:11:48.169590 #31396]  INFO -- : Documents: 16445, ds: 12965, diag: 3480, glob: /mnt/datasets/Tracking/ARGOS/archive/2012/**/*

http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2013-01-01..2014-01-01
I, [2015-03-12T10:15:41.722159 #31481]  INFO -- : Documents: 36640, ds: 27840, diag: 8800, glob: /mnt/datasets/Tracking/ARGOS/archive/2013/**/*

http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2014-01-01..2014-03-01&not-type=xml
I, [2015-03-12T10:04:00.034353 #31301]  INFO -- : Documents: 14469, ds: 11030, diag: 3439, glob: /mnt/datasets/Tracking/ARGOS/archive/2014/**/*

The output of these three commands are piped to the npolar-api command.

```
./bin/argos-ascii /mnt/datasets/Tracking/ARGOS/archive/2012/2012-09 --filter='lambda {|d| ["113909"].include? d[:platform].to_s }' | npolar-api -XPOST http://localhost:9393/tracking/arctic-fox\?overwrite\=true -d@-
```

#### JSON <- Argos XML
Argos XML is converted to JSON using [XSLT] (), just prior to [publishing] (https://github.com/npolar/api.npolar.no/blob/master/external/cls.fr/arctic-fox/bin/---).

### Harvesting
Nighly cron job using [argos-soap](https://github.com/npolar/argos-ruby) --download

### Integrity check
[@todo]

### Publishing

A. One-off publishing of the two disk archives
```sh
[external@gustav ~]$ /home/external/api.npolar.no/bin/npolar-api-post-glob https://api.npolar.no/tracking/arctic-fox /mnt/datasets/Tracking/ARGOS/arctic-fox/**/*.json
[external@gustav ~]$ /home/external/api.npolar.no/external/cls.fr/arctic-fox/bin/npolar-argos-publish-arctic-fox-xml https://api.npolar.no/tracking/arctic-fox "/mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/*/program-11660/platform-*/argos*.xml"
```

B. Data publishing
Nightly cron job

### Security and authorization
Disk archive writes are reserved to staff at the Norwegian Polar Data Centre.
Arctic fox tracking data is restricted, only the external user can create, update or delete data, while only the principal investigators and data centre staff may at the moment access the data.
