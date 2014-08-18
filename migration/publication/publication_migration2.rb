# encoding: utf-8
require_relative "../../lib/publication"

# $ ./bin/npolar-api-migrator /publication PublicationMigration2 --really=false > /dev/null
class PublicationMigration2

  attr_accessor :log

  def migrations
    [remove_wrong_offset_in_published_sort]
  end

  def model
    Publication.new
  end

  # Fix for published datetimes spilling over in the previous year in UTC
  # Production: 2014-08-15T08:46:47Z (882 documents)
  # http://api.npolar.no/editlog/a63ae845-cd83-4cb5-9399-102a48459384
  def remove_wrong_offset_in_published_sort
    lambda {|d|
      if d.published_sort =~ /T00\:00\:00[+-]\d\d\:\d\d$/
        log.warn d.published_sort
        p = DateTime.parse d.published_sort
        dt = DateTime.new(p.year, p.month, p.day, 12, 0, 0, 0)
        d.published_sort = dt.to_time.utc.iso8601
        log.info d.published_sort
      end
      d
    }
  end
end
