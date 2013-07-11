#!/bin/sh
# ./solr_delete_id.sh http://dbmaster.data.npolar.no:8983/solr/api 8f80087e-8c7b-11e2-bc03-005056ad0004
echo "Deleting id $2 at $1"
curl -kniXPOST $1/update --data-binary "<delete><query>id:$2</query></delete>" -H 'Content-Type:text/xml; charset=utf-8'
curl -kniXPOST $1/update --data-binary '<commit/>' -H 'Content-Type:text/xml; charset=utf-8'
