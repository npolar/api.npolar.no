require 'json'
require 'csv'

# usage: ruby couch-archiver.rb <couch_json_dump_file> <csv_output_file>
# json_dump can be obtained by doing:
# curl http://<couch_url>/<db_name>/_all_docs?include_docs=true > all.json
#

in_path = ARGV[0]
out_path = ARGV[1]

ignore = ['_id', 'id', '_rev', 'rev', 'created_by', 'updated_by', 'schema', 'updated', 'created']

content = File.read(in_path)
couch = JSON.parse(content)
rows = couch['rows']
docs = []

rows.each do |row|
  doc = {}
  row['doc'].each do |key, val|
    if !ignore.include? key
      doc[key] = val
    end
  end

  docs << doc
end

CSV.open(out_path, "wb") do |csv|
  csv << docs[0].keys
  docs.each do |doc|
    csv << doc.values
  end
end
