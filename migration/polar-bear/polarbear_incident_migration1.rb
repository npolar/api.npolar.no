# encoding: utf-8
# $ ./bin/npolar-api-migrator /polar-bear/incident PolarbearIncidentMigration1 --really=false > /dev/null

class PolarbearIncidentMigration1

  attr_accessor :log

  def model
    PolarbearIncident.new
  end

  def migrations
    [remove]
  end

  def remove
    lambda {|d|

      if d.author?
        d.delete :author
      end

      if d.datetime?
        d.delete :datetime
      end

      if d.incident?
        if d.incident.timezone?
          d.incident.delete :timezone
        end
      end

      log.info d.to_json
      d
    }
  end
end
