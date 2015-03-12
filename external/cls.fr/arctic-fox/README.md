# Arctix fox tracking

## Data
* https://api.npolar.no/tracking/arctic-fox/?q= [restricted]

## Metadata
* [Dataset](https://data.npolar.no/dataset/e62ec1a4-9aac-4a2f-9973-76d772c87f94)
* Project (URI)?
* Data provider: [CLS](http://cls.fr)
* Platform vendor: Sirtrack
* [Data viewer]()
* [Platform deployments](http://api.npolar.no/tracking/deployment/?q=&filter-vendor=Followit&object=Arctic+fox)

## Archive
Original DS/DIAG text files
* /mnt/datasets/Tracking/ARGOS/archive

## JSON from legacy Argos DS/DIAG text files

* /mnt/datasets/Tracking/ARGOS/arctic-fox

```sh
[external@gustav ~]$ YEAR=2012 && argos-ascii --debug --filter='lambda {|d| ["113907","113908","113908","113909","113909","113910","113911","113912","113913","113913","113914","113915","131424","131425","131426","131427","131428"].include? d[:platform].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR --dest=/mnt/datasets/Tracking/ARGOS/arctic-fox/$YEAR
I, [2015-03-12T10:11:48.169590 #31396]  INFO -- : Documents: 16445, ds: 12965, diag: 3480, bundle: 43248db3bd893c3c2d1701cd0d407b5d132b842e, glob: /mnt/datasets/Tracking/ARGOS/archive/2012/**/*
```
http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2012-01-01..2013-01-01

```sh
[external@gustav ~]$ YEAR=2013 && argos-ascii --debug --filter='lambda {|d| ["113907","113908","113908","113909","113909","113910","113911","113912","113913","113913","113914","113915","131424","131425","131426","131427","131428"].include? d[:platform].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR --dest=/mnt/datasets/Tracking/ARGOS/arctic-fox/$YEAR
I, [2015-03-12T10:15:41.722159 #31481]  INFO -- : Documents: 36640, ds: 27840, diag: 8800, bundle: 28b04e0410b124e5893ed378b4f38a56d8bf77b7, glob: /mnt/datasets/Tracking/ARGOS/archive/2013/**/*
```
http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2013-01-01..2014-01-01

```sh
[external@gustav ~]$ YEAR=2014 && argos-ascii --debug --filter='lambda {|d| ["113907","113908","113908","113909","113909","113910","113911","113912","113913","113913","113914","113915","131424","131425","131426","131427","131428"].include? d[:platform].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR --dest=/mnt/datasets/Tracking/ARGOS/arctic-fox/$YEAR
I, [2015-03-12T10:04:00.034353 #31301]  INFO -- : Documents: 14469, ds: 11030, diag: 3439, bundle: 968100dfc199eae7632d721206866597d85f8c53, glob: /mnt/datasets/Tracking/ARGOS/archive/2014/**/*
```
http://api.npolar.no/tracking/arctic-fox/?q=&filter-measured=2014-01-01..2014-03-01&not-type=xml

## Harvesting
Nighly cron job

## Publishing

Nightly cron job