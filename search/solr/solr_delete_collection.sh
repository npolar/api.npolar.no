#!/bin/sh
#  ./solr_delete_collection.sh http://localhost:8983/solr/api mapping placename
echo "Deleting $1 $2 $3"
curl -kniXPOST $1/update --data-binary "<delete><query>workspace:$2 AND collection:$3</query></delete>" -H 'Content-Type:text/xml; charset=utf-8'
curl -kniXPOST $1/update --data-binary '<commit/>' -H 'Content-Type:text/xml; charset=utf-8'
