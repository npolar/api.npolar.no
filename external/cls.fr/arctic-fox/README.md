# Arctic fox tracking data management

Data is available in the [Arctic fox tracking](https://api.npolar.no/tracking/arctic-fox/?q=) API [restricted].

This file contains behind-the-scenes documentation of the data flow: harvesting, archiving, processing, publishing.

For information on how to access the data, visit the [Tracking Arctic fox API](https://github.com/npolar/api.npolar.no/wiki/Tracking-Arctic-fox-API) wiki.

* Data provider: [CLS](http://cls.fr)
* Platform model: KiwiSat303
* Platform vendor: Sirtrack

### Archive
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

### Publishing


```sh
[external@gustav ~]$ /home/external/api.npolar.no/bin/npolar-api-post-glob https://api.npolar.no/tracking/arctic-fox /mnt/datasets/Tracking/ARGOS/arctic-fox/**/*.json
[external@gustav ~]$ /home/external/api.npolar.no/external/cls.fr/arctic-fox/bin/npolar-argos-publish-arctic-fox-xml https://api.npolar.no/tracking/arctic-fox "/mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/*/program-11660/platform-*/argos*.xml"
```

Nightly cron job