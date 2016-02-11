# nina.no

## SEATRACK data
The [Seabird tracking API](http://api.npolar.no/tracking/seabird/?q=) is populated with data from the SEATRACK database at [NINA](http://nina.no).

### JSON from SEATRACK database dump

NINA staff rsyncs SEATRACK GLS logger data as CSV to `seatrack@api.npolar.no:~/seatrack-db/v{N}/{year}/*.csv` where N is database_version.
Updated rows has `data_version` > 1.

```csv
id;date_time;logger;logger_id;logger_model;year_tracked;year_deployed;year_retrieved;ring_number;euring_code;species;colony;lon_raw;lat_raw;lon_smooth1;lat_smooth1;lon_smooth2;lat_smooth2;disttocol_s2;eqfilter1;eqfilter2;eqfilter3;lat_smooth2_eqfilt3;sex;morph;subspecies;age;col_lon;col_lat;tfirst;tsecond;twl_type;conf;sun;software;light_threshold;analyzer;data_responsible;logger_yeartracked;posdata_file;import_date;data_version;database_version
53b0a458-6968-4d2b-b8a9-08c5f9f61495;2009-09-09 11:07:00;2987_mk9;2987;mk9;2009_10;2009;2010;CA23058;NOS;Common eider;Kongsfjorden;12.57698132;78.96406474;11.72347258;79.04029489;10.67001216;78.90865197;33.11735052;1;1;1;78.90865197;female;NA;NA;adult_unknown;12.217;78.9;2009-09-09 01:17:00;2009-09-09 20:58:00;1;9;-4;Bastrack;10;B_Moe;B_Moe;2987_mk9_2009_10;eider_positions_2010_2013;2016-01-22;1;1
```

JSON <- CSV 
```sh
[api@app.data seatrack] $ cat seatrack-db/v1/2016/seatrack_export_*-semicolon.csv | ./bin/seatrack-csv-to-json > seed/seatrack-db-v1.json
```
### Kernel density estimates
Provided by [Benjamin Merkel](http://www.npolar.no/en/people/benjamin.merkel/)


## Seabird API

Publish data
```
[api@app.data ~]$ npolar-api --debug -XPOST "/tracking/seabird?filter-geometry.type=Point" -d@external/nina.no/seatrack/seed/seatrack-db-v1.json 
```

# Creating the Seabird tracking API

[api@app.data ~]$ curl -XDELETE $NPOLAR_API_COUCHDB/tracking-seabird
[api@app.data ~]$ curl -XPUT $NPOLAR_API_COUCHDB/tracking-seabird
[api@app.data api.npolar.no]$ ./bin/npolar-api-elasticsearch tracking-seabird-api.json
[api@app.data ~]$ npolar-api -XPOST -d@seed/service/tracking-seabird-api.json /service
[api@app.data ~]# service api restart