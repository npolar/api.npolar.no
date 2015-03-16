# Arctic fox GPS tracking data management

This file contains behind-the-scenes documentation of the data flow of Arctic fox position data.
For information on how to access the data, visit the [Tracking Arctic fox API](https://github.com/npolar/api.npolar.no/wiki/Tracking-Arctic-fox-API) wiki.

### Data flow
Data management involves harvesting, archiving, processing, publishing and documenting the data.

Data is published in the [Arctic fox tracking](https://api.npolar.no/tracking/arctic-fox/?q=) API (**restricted**),
a [JSON](https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/api/json.rb) API.

Notice that the API has a separate CouchDB database, but share the Elasticsearch index ```tracking``` with other biological tracking data.

* Data provider: [CLS](http://cls.fr)
* Positioning technology: [Argos](http://en.wikipedia.org/wiki/Argos_system) system
* Platform vendor: [Sirtrack](http://sirtrack.com)
* Platform model: [KiwiSat303](http://www.sirtrack.com/images/pdfs/303_K3HVHF.pdf)
* Sensor data [decoder](https://github.com/npolar/argos-ruby/blob/master/lib/argos/kiwisat303_decoder.rb))
* Platform [deployments](http://api.npolar.no/tracking/deployment/?q=&filter-object=Arctic+fox&filter-technology=argos)
* [Service](http://api.npolar.no/service/tracking-arctic-fox-api) metadata
* Dataset [metadata](https://data.npolar.no/dataset/e62ec1a4-9aac-4a2f-9973-76d772c87f94)

Legacy Argos [DS]/[DIAG] files are converted to [Tracking JSON] using [argos-ascii](https://github.com/npolar/argos-ruby/wiki/argos-ascii) and published in a one time-operation (detailed below).

From 1 March 2014 all Argos data XML is downloaded nightly before being converted to JSON and published.
The processing chain involves:

1. Harvesting. Argos data XMl for the last 20 days is [downloaded](https://github.com/npolar/argos-ruby/blob/master/lib/argos/download.rb) each night from CLS from their SOAP web service accesses via the [argos-soap](https://github.com/npolar/argos-ruby/wiki/argos-soap) commmand
2. Archiving. Data is archived on disk untouched in one file per platform per day
3. Integrity check. All files in the disk archive are fingerprinted and the number of messages is compared with ethe number of documents in the tracking API
5. Preprocessing. Any files not already in the API are converted to JSON using [XSLT](https://github.com/npolar/argos-ruby/blob/master/lib/argos/_xslt/argos-json.xslt)
6. Publishing. HTTP POST containing Array of JSON per platform per day
7. Postprocessing. The harvested data from CLS is merged with [platform metadata](https://github.com/npolar/api.npolar.no/wiki/Tracking-Deployment-API).
8. Validation. JSON schema.
9. Storage in CouchDB
10. Search engine indexing via Elasticsearch's river plugin (listens to CouchDB changes stream)  

Steps 1-6 occurs client side, steps 7-9 occurs in the Ruby model [Tracking](https://github.com/npolar/api.npolar.no/blob/master/lib/tracking.rb)#before_save.

A word about merging of platform deployment metadata (step 6).

Pay special attention to the ```deployed``` time: Only messages with timestamp after deployed are marked with ```individual```, ```species```, and ```object``` information from the deployment API.

For reused platforms, the ```terminated``` time is critical to set for the first deployment, even if it's not known precisely. If there is no terminated time for the reused platform, it's impossible to know wether a given message is from the first or second deployment.

If the tracking deployment information changes, tracking data for the affected platforns needs to be republished to propogate the changes to each individual tracking document.

A planned improvement to the publishing process is to trigger publishing when tracking platform deployment dates change.

### Disk archive

Original Argos DS/DIAG files: /mnt/datasets/Tracking/ARGOS/archive

Original Argos XML files: /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/*/program-11660/platform-*/argos*.xml

#### JSON <- DS/DIAG
Legacy Argos DS/DIAG text files are converted to JSON using [argos-ruby](https://github.com/npolar/argos-ruby) and stored at /mnt/datasets/Tracking/ARGOS/arctic-fox/**/*.json

For each of the years 2012, 2013, and 2014:
```sh
[external@gustav ~]$ YEAR=2012 && argos-ascii --debug --filter='lambda {|d| ["113907","113908","113908","113909","113909","113910","113911","113912","113913","113913","113914","113915","131424","131425","131426","131427","131428"].include? d[:platform].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR --dest=/mnt/datasets/Tracking/ARGOS/arctic-fox/$YEAR
```

http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2012-01-01..2013-01-01
I, [2015-03-12T10:11:48.169590 #31396]  INFO -- : Documents: 16445, ds: 12965, diag: 3480, bundle: 43248db3bd893c3c2d1701cd0d407b5d132b842e, glob: /mnt/datasets/Tracking/ARGOS/archive/2012/**/*

http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2013-01-01..2014-01-01
I, [2015-03-12T10:15:41.722159 #31481]  INFO -- : Documents: 36640, ds: 27840, diag: 8800, bundle: 28b04e0410b124e5893ed378b4f38a56d8bf77b7, glob: /mnt/datasets/Tracking/ARGOS/archive/2013/**/*

http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2014-01-01..2014-03-01&not-type=xml
I, [2015-03-12T10:04:00.034353 #31301]  INFO -- : Documents: 14469, ds: 11030, diag: 3439, bundle: 968100dfc199eae7632d721206866597d85f8c53, glob: /mnt/datasets/Tracking/ARGOS/archive/2014/**/*

#### JSON <- Argos XML
Converted on-the-fly by the [publishing script](https://github.com/npolar/api.npolar.no/blob/master/external/cls.fr/arctic-fox/bin/---)

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

B. Missing data publishing
Nightly cron job

### Security and authorization
Disk archive writes are reserved to staff at the Norwegian Polar Data Centre.
Arctic fox tracking data is restricted, only the external user can create, update or delete data, while only the principal investigators and data centre staff may at the moment access the data.