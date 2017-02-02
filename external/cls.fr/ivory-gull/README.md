# Ivory gull tracking data management

Argos program 10660 (and potentially 32660)

## Platform deployments

**Extract list of platforms**

* http://api.npolar.no/tracking/deployment/?q=&filter-species=Pagophila+eburnea

```ruby
require "json"; require "open-uri";
uri = "http://api.npolar.no/tracking/deployment/?q=&filter-species=Pagophila+eburnea&fields=platform&format=json&variant=array"
platforms = JSON.parse(open(uri).read).map {|d| d["platform"].to_s }.sort.uniq
```

```json
{ "platforms": [52054, 52055, 52056, 52058, 52059, 52089, 52090, 52092, 52099, 52101, 52178, 52179, 52182, 52183, 52188, 52190, 52192, 52281, 52284, 52453, 52454, 52457, 52467, 52470, 52473, 61132, 61133, 61134, 61135, 61138, 61139, 61140, 61141, 61143, 61144, 74878, 74879, 74880, 74881, 74882, 74883, 74884, 74885, 74886, 74887, 74888, 74889, 74890, 74891, 74892, 74893, 74894, 74895, 74896, 74897, 108702, 108703, 108704, 113916, 113917, 113918, 113919, 113920, 113921, 113922, 113923, 113924, 113925, 113926, 113927, 113928, 113929, 113930, 113931, 113932, 113933, 113934, 113935, 113936, 113937, 113938, 113939, 113940, 129642, 129643, 129644, 129645, 129646, 129652, 129653, 129654, 129655, 129656] }
```


# Actual 53 platforms (from DS files) for program 10666 in 2013-2014

```json
{"platforms": [52054, 52056, 52058, 52059, 52099, 52101, 52192, 52281, 52454, 52457, 52467, 52470, 52473, 61141, 108704, 113916, 113918, 113919, 113920, 113921, 113922, 113923, 113924, 113925, 113926, 113927, 113928, 113930, 113931, 113932, 113933, 113934, 113935, 113936, 113937, 113938, 113939, 113940, 129642, 129643, 129644, 129645, 129646, 129647, 129648, 129649, 129650, 129651, 129652, 129653, 129654, 129655, 129656] }
```

## Extracting data

Extracted files
```
ch@arken:~/npolar/argos-ruby$ sha1sum $SEED/*
ad96b87196065a73bdbfb9573c48b147c9105e8e  /mnt/datasets/Tracking/ARGOS/seed/ivory-gull/ivory-gull-argos-2013-DIAG-filtered.json
aa4ca768ae4374fcec750edf62eb5b72a986fc93  /mnt/datasets/Tracking/ARGOS/seed/ivory-gull/ivory-gull-argos-2013.json
12161192e33ff7f0049bf0649e4a7b86d8001778  /mnt/datasets/Tracking/ARGOS/seed/ivory-gull/ivory-gull-argos-2014-DIAG-filtered.json
508b90f279a296434c8c4ea4eb3662140e3b5ba2  /mnt/datasets/Tracking/ARGOS/seed/ivory-gull/ivory-gull-argos-2014.json
04805cb0a0d45f6d5f68ec5462fce150780e7748  /mnt/datasets/Tracking/ARGOS/seed/ivory-gull/ivory-gull-argos-from-xml.json
```

$ cd npolar/argos-ruby
$ MIDL=/mnt/felles/Midlertidig/data.npolar.no/tracking/ivory-gull
$ SEED=/mnt/datasets/Tracking/ARGOS/seed/ivory-gull

### DS

**-> CSV**
YEAR=2013 && ./bin/argos-ascii --debug --format=csv --filter='lambda {|d| ["10660"].include? d[:program].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > $MIDL/ivory-gull-argos-$YEAR.csv
YEAR=2014 && ./bin/argos-ascii --debug --format=csv --filter='lambda {|d| ["10660"].include? d[:program].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > $MIDL/ivory-gull-argos-$YEAR.csv

**-> JSON**
YEAR=2013 && ./bin/argos-ascii --debug --filter='lambda {|d| ["10660"].include? d[:program].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > $SEED/ivory-gull-argos-$YEAR.json
YEAR=2014 && ./bin/argos-ascii --debug --filter='lambda {|d| ["10660"].include? d[:program].to_s }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > $SEED/ivory-gull-argos-$YEAR.json

**Counts**
Documents: 217769, ds: 217769, diag: 0, bundle: 82d5640e5a2c420bf56164ff2812f514001f8734, glob: /mnt/datasets/Tracking/ARGOS/archive/2013/**/*
Documents: 22009, ds: 22009, diag: 0, bundle: 3cef80eea47e234da9d4594957899f4ee0ab6e1f, glob: /mnt/datasets/Tracking/ARGOS/archive/2014/**/*

### DIAG
**-> CSV**
YEAR=2013 && ./bin/argos-ascii --debug --format=csv --filter='lambda {|d| ["diag"].include? d[:type].to_s and [113919,129654,129652,129656,113930,113920,113918,52101,113926,52056,129642,129653,129655,129646,129644,52059,129643,129645,113928,52457,113923,113922,52099,52454,52467,113924,113921,113925,61141,52054,129647,129649,129651,113927,129650,113938,113940,113935,113934,129648,113936,113937,113932,113939,113933,113931,52058,52192,52281,52470,52473,108704,113916].include? d[:platform].to_i }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > $MIDL/ivory-gull-argos-$YEAR-DIAG-filtered.csv
YEAR=2014 && ./bin/argos-ascii --debug --format=csv --filter='lambda {|d| ["diag"].include? d[:type].to_s and [113919,129654,129652,129656,113930,113920,113918,52101,113926,52056,129642,129653,129655,129646,129644,52059,129643,129645,113928,52457,113923,113922,52099,52454,52467,113924,113921,113925,61141,52054,129647,129649,129651,113927,129650,113938,113940,113935,113934,129648,113936,113937,113932,113939,113933,113931,52058,52192,52281,52470,52473,108704,113916].include? d[:platform].to_i }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > $MIDL/ivory-gull-argos-$YEAR-DIAG-filtered.csv

**-> JSON**
YEAR=2013 && ./bin/argos-ascii --debug --filter='lambda {|d| ["diag"].include? d[:type].to_s and [113919,129654,129652,129656,113930,113920,113918,52101,113926,52056,129642,129653,129655,129646,129644,52059,129643,129645,113928,52457,113923,113922,52099,52454,52467,113924,113921,113925,61141,52054,129647,129649,129651,113927,129650,113938,113940,113935,113934,129648,113936,113937,113932,113939,113933,113931,52058,52192,52281,52470,52473,108704,113916].include? d[:platform].to_i }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > $SEED/ivory-gull-argos-$YEAR-DIAG-filtered.json
YEAR=2014 && ./bin/argos-ascii --debug --filter='lambda {|d| ["diag"].include? d[:type].to_s and [113919,129654,129652,129656,113930,113920,113918,52101,113926,52056,129642,129653,129655,129646,129644,52059,129643,129645,113928,52457,113923,113922,52099,52454,52467,113924,113921,113925,61141,52054,129647,129649,129651,113927,129650,113938,113940,113935,113934,129648,113936,113937,113932,113939,113933,113931,52058,52192,52281,52470,52473,108704,113916].include? d[:platform].to_i }' /mnt/datasets/Tracking/ARGOS/archive/$YEAR > $SEED/ivory-gull-argos-$YEAR-DIAG-filtered.json

**Counts**
Documents: 37669, ds: 0, diag: 37669, bundle: 8e4a4d5071fb1aa34b0a83e06518a2e20d046aca, glob: /mnt/datasets/Tracking/ARGOS/archive/2013/**/*
Documents: 4094, ds: 0, diag: 4094, bundle: 8f22444ce456f55a867167be16e75910679eeb04, glob: /mnt/datasets/Tracking/ARGOS/archive/2014/**/*


### XML
ch@arken:~/npolar/api.npolar.no$ ./external/cls.fr/bin/npolar-argos-xml-to-json /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/*/program-10660 > $SEED/ivory-gull-argos-from-xml.json
D, [2017-02-02T15:09:56.215205 #13190] DEBUG -- : +2 messages / 271433  <- /mnt/datasets/Tracking/ARGOS/ws-argos.cls.fr/2014/program-10660/platform-61141/argos-2014-08-26-platform-61141.xml

## Publishing data

npolar-api -XPOST http://apptest.data.npolar.no:9000/tracking/ivory-gull -d@$SEED/ivory-gull-argos-2013.json
npolar-api -XPOST http://apptest.data.npolar.no:9000/tracking/ivory-gull -d@$SEED/ivory-gull-argos-2014.json

npolar-api --debug -XPOST http://apptest.data.npolar.no:9000/tracking/ivory-gull -d@$SEED/ivory-gull-argos-2013-DIAG-filtered.json
npolar-api --debug -XPOST http://apptest.data.npolar.no:9000/tracking/ivory-gull -d@$SEED/ivory-gull-argos-2014-DIAG-filtered.json

npolar-api --debug -XPOST http://apptest.data.npolar.no:9000/tracking/ivory-gull -d@$SEED/ivory-gull-argos-from-xml.json

## Obtaining data

Service: http://apptest.data.npolar.no:9000/tracking/ivory-gull/?q= [Restricted]

DS fields
"program,platform,lines,sensors,satellite,lc,positioned,latitude,longitude,altitude,headers,measured,identical,sensor_data,technology,type,cardinality,warn",

DIAG fields:

XML fields:

Formats
* CSV: http://apptest.data.npolar.no:9000/tracking/ivory-gull/?q=&format=csv
* JSON: http://apptest.data.npolar.no:9000/tracking/ivory-gull/?q=&format=json&variant=array
* GeoJSON: http://apptest.data.npolar.no:9000/tracking/ivory-gull/?q=&format=geojson

CSV to disk
$ curl "http://apptest.data.npolar.no:9000/tracking/ivory-gull/?q=&format=csv&limit=all" > "$MIDL/ivory-gull-argos-all.csv"