class EditLog

  def self.save_lambda(config={})
    lambda {|edit|

      require "faraday"

      uri = config[:uri]
      username = config[:username]
      password = config[:password]
      database = config[:database].gsub(/^\//, "")
     
      if username.nil? and password.nil? and uri =~ /\:\/\/(.+)[:](.+)\@/
        username, password = $1, $2
      end
      id = edit[:id]

      faraday = Faraday.new(uri)
      
      faraday.basic_auth username, password
      faraday.response :logger # Log to STDOUT
      response = faraday.put do |request|
        request.url "/#{database}/#{id}"
        request.headers["Content-Type"] = "application/json"
        request.body = edit.to_json
      end
      if response.status != 201
        raise "Failed insering editlog"
      end
      response
      
    }
  end

  def self.index_lambda(config={})
    lambda {|edit|

      require "elasticsearch"
      id = edit[:id]
      client = Elasticsearch::Client.new(config)
      client.index index: "editlog", type: "item", id: id, body: edit.to_json
     }
  end

end