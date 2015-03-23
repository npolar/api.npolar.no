# encoding: utf-8
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

      edit_text = Yajl::Encoder.encode(edit)


      faraday = Faraday.new(uri)

      if not (username.nil? or password.nil?)
        faraday.basic_auth username, password
      end
      faraday.response :logger # Log to STDOUT
      response = faraday.put do |request|
        request.url "/#{database}/#{id}"
        request.headers["Content-Type"] = "application/json; charset=utf-8"
        request.body = edit_text
      end
      if response.status != 201
        raise "Failed insering editlog, response status: #{response.status}"
      end
      response

    }
  end

  def self.index_lambda(config={})
    lambda {|edit|

      #require "elasticsearch"
      #id = edit[:id]

      #if not edit[:request][:body].nil?
      #  edit[:request][:body].delete
      #end

      #edit_text = Yajl::Encoder.encode(edit)
      #client = Elasticsearch::Client.new(config)
      #client.index index: "editlog", type: "item", id: id, body: edit_text
     }
  end

end
