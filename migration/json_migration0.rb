# encoding: utf-8

# $ ./bin/npolar-api-migrator [https://api.npolar.no]/endpoint ::JsonMigration0 --really=false > /dev/null

class JsonMigration0

  attr_accessor :log

  def migrations
    [fix_mail_addresses]
  end
  
  def fix_mail_addresses
    lambda {|d|
      
      if d.created_by =~ /[%]40/
        d.created_by = d.created_by.gsub(/[%]40/, "@")
      end
      if d.updated_by =~ /[%]40/
        d.updated_by = d.updated_by.gsub(/[%]40/, "@")
      end
      
      d
    }
  end
end