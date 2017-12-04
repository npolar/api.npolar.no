# Arctic fox tracking data management

This file contains behind-the-scenes documentation of the data management of Arctic fox telemetry data,
obtained via the [Argos]() system.

In a nutshell, every night
* Argos data XML from the last 20 days are harvested to disk `/mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/`
* Data for known platforms (ie. those defined in the [Tracking deployment API](http://api.npolar.no/tracking/deployment/?q=&filter-object=Arctic+fox) is then published into the [Arctic fox tracking API](http://api.npolar.no/tracking/arctic-fox) [restricted access].

See [Argos data management](https://github.com/npolar/api.npolar.no/tree/master/external/cls.fr/README.) for details on Argos data management.

For dataset metadata, including principal investigators and information on accessing and citing the dataset, see https://data.npolar.no/dataset/8337bbf0-85e9-49cb-b070-9fa5fe503c82

For detailed information on how to access the data, visit the [Tracking Arctic fox API wiki](https://github.com/npolar/api.npolar.no/wiki/Arctic-fox-tracking-API).

## System overview

Data is published in the [Arctic fox tracking API](https://api.npolar.no/tracking/arctic-fox/?q=) (**restricted**), a REST-style data service, powered by [Npolar::Api::Json](https://github.com/npolar/api.npolar.no/blob/master/lib/npolar/api/json.rb).

Several key data management aspects are defined in the [Service definition](http://api.npolar.no/service/tracking-arctic-fox-api): database, search engine, authorization rules, model,schema,accepted and outgoing formats.

The platform metadata for Arctic foxes is maintained in the [Tracking Deployment API](http://api.npolar.no/tracking/deployment/?q=&filter-object=Arctic+fox)

Currently all transmitter platforms use the Argos system and all units are the same model:
* Data provider: [CLS](http://cls.fr)
* Positioning technology: [Argos](http://en.wikipedia.org/wiki/Argos_system) system
* Platform vendor: [Sirtrack](http://sirtrack.com)
* Platform model: [KiwiSat303](http://www.sirtrack.com/images/pdfs/303_K3HVHF.pdf)
* Sensor data [decoder](https://github.com/npolar/argos-ruby/blob/master/lib/argos/kiwisat303_decoder.rb)

## Disk archive

Original Argos DS/DIAG files: /mnt/datasets/Tracking/ARGOS/archive

Original Argos XML files: /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/{year}/program-11660/platform-{platform}/argos*.xml

### JSON <- DS/DIAG
Legacy Argos DS/DIAG text files are converted to JSON using [argos-ruby](https://github.com/npolar/argos-ruby) and stored at /mnt/datasets/Tracking/ARGOS/arctic-fox/**/*.json

For each of the years 2012, 2013, and 2014:
```sh
# require "json"; require "open-uri"; JSON.parse(open("http://api.npolar.no/tracking/deployment/?q=&filter-object=Arctic+fox&fields=platform&format=json&variant=array").read).map {|d| d["platform"].to_s }.sort.uniq

YEAR=2012 && /home/external/argos-ruby/bin/argos-ascii --debug --filter='lambda {|d| ["113907", "113908", "113909", "113910", "113911", "113912", "113913", "113914", "113915", "131424", "131425", "131426", "131427", "131428"].include? d[:platform].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > /mnt/datasets/Tracking/ARGOS/seed/arctic-fox/arctic-fox-$YEAR.json
YEAR=2013 && /home/external/argos-ruby/bin/argos-ascii --debug --filter='lambda {|d| ["113907", "113908", "113909", "113910", "113911", "113912", "113913", "113914", "113915", "131424", "131425", "131426", "131427", "131428"].include? d[:platform].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > /mnt/datasets/Tracking/ARGOS/seed/arctic-fox/arctic-fox-$YEAR.json
YEAR=2014 && /home/external/argos-ruby/bin/argos-ascii --debug --filter='lambda {|d| ["113907", "113908", "113909", "113910", "113911", "113912", "113913", "113914", "113915", "131424", "131425", "131426", "131427", "131428"].include? d[:platform].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > /mnt/datasets/Tracking/ARGOS/seed/arctic-fox/arctic-fox-$YEAR.json

```

I, [2015-03-12T10:11:48.169590 #31396]  INFO -- : Documents: 16445, ds: 12965, diag: 3480, glob: /mnt/datasets/Tracking/ARGOS/archive/2012/**/*
http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2012-01-01..2013-01-01

I, [2015-03-12T10:15:41.722159 #31481]  INFO -- : Documents: 36640, ds: 27840, diag: 8800, glob: /mnt/datasets/Tracking/ARGOS/archive/2013/**/*
http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2013-01-01..2014-01-01

I, [2015-03-12T10:04:00.034353 #31301]  INFO -- : Documents: 14469, ds: 11030, diag: 3439, glob: /mnt/datasets/Tracking/ARGOS/archive/2014/**/*
http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2014-01-01..2014-03-01

year-measured
# 2012 (16445) 2013 (36640) 2014 (65926) 2015 (41960) 2016 (31503) 2017 (4789)
# 2012 (16445) 2013 (36640) 2014 (14469 DS/DIAG + 51243 XML = 65712)

2014 XML: 51305
2015 XML: 41960
2016 XML: 31503


### JSON <- Argos XML

Argos XML is converted to JSON using [XSLT] (), just prior to [publishing]

### Harvesting

Nighly cron job using [argos-soap](https://github.com/npolar/argos-ruby) --download, see [example debug output](https://raw.githubusercontent.com/npolar/api.npolar.no/master/external/cls.fr/arctic-fox/argos-soap-download.md)

### Integrity check

[@todo]

### Publishing

A. One-off publishing of the archives

```sh
# DS/DIAG
[external@gustav ~]$ npolar-api --debug -XPOST /tracking/arctic-fox -d@/mnt/datasets/Tracking/ARGOS/seed/arctic-fox/arctic-fox-2012.json
[external@gustav ~]$ npolar-api --debug -XPOST /tracking/arctic-fox -d@/mnt/datasets/Tracking/ARGOS/seed/arctic-fox/arctic-fox-2013.json
[external@gustav ~]$ npolar-api --debug -XPOST /tracking/arctic-fox -d@/mnt/datasets/Tracking/ARGOS/seed/arctic-fox/arctic-fox-2014.json
# XML
YEAR=2014 && /home/external/api.npolar.no/external/cls.fr/bin/npolar-argos-publish-xml /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/$YEAR/program-11660 https://api.npolar.no/tracking/arctic-fox
YEAR=2015 && /home/external/api.npolar.no/external/cls.fr/bin/npolar-argos-publish-xml /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/$YEAR/program-11660 https://api.npolar.no/tracking/arctic-fox
YEAR=2016 && /home/external/api.npolar.no/external/cls.fr/bin/npolar-argos-publish-xml /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/$YEAR/program-11660 https://api.npolar.no/tracking/arctic-fox
YEAR=2017 && /home/external/api.npolar.no/external/cls.fr/bin/npolar-argos-publish-xml /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/$YEAR/program-11660 https://api.npolar.no/tracking/arctic-fox
```

B. Data publishing

Nightly cron job