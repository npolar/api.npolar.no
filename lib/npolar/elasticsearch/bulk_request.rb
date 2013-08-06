module Npolar
  module ElasticSearch
    
    # [Functionality]
    #   Class for building and executing ElasticSearch bulk requests.
    #   Depending on the number of documents contained in the bulk
    #   array a number of workers will be spawned that process the
    #   data in parallel and post it to the search engine as soon
    #   as the processing is done.
    #
    # [Authors]
    #   - Ruben Dens
    #
    # @example
    #   conf = {:uri => 'http://my.elasticsearch.com/', :operation => 'index', :index => 'myIndex', :type => 'myDocType', :bulk_size => 200}
    #   document_array = JSON.parase(File.open(my_document_array.json).read)
    #   request = Npolar::ElasticSearch::BulkRequest.new(document_array, conf)
    #
    
    class BulkRequest
      
      CONFIG = {
        :uri => 'http://localhost:9200/',
        :bulk_size => 100,
        :operation => 'index',
        :index => '',
        :type => ''
      }
      
      attr_accessor :config, :data, :log
      
      def initialize(data_array, config = {})
        self.data = data_array
        self.config = CONFIG.merge(config)
        self.log = ::Logger.new(STDERR)
      end
      
      # @see #build_request_document
      # @see Npolar::ElasticSearch::Http
      def execute
        
        workers = 0
        pid = nil
        
        if data.is_a?( Array )
          # Cut the document array into managable slices
          data.each_slice(config[:bulk_size]) do |slice|
            
            # For each slice create a request document 
            # and post it to the search engines _bulk interface
            pid = fork do
              body = build_request_document(slice)
              response = bulk_post(body)
              log.info "Indexing of #{slice.size} items exited with status #{response.status}."
            end
            
            unless workers == 7
              workers = workers + 1
            else
              Process.wait(pid)
              GC.start
              workers = 0
            end
          end    
        end
        
      end
      
      # Build a bulk request document for all the items in a slice (Array).
      def build_request_document(slice)
        document = ""
        
        # For each item in the slice we generate the appropriate operation syntax
        slice.each do |item|
          document += {config[:operation] => {:_index => config[:index],:_type => config[:type],:_id => item['id']}}.to_json + "\n"
          document += item.to_json + "\n"
        end
        
        document
      end
      
      # protected
      
      def http
        Faraday.new(:url => config[:uri]) do |faraday|
          faraday.request  :url_encoded             # form-encode POST params
          faraday.response :logger                  # log requests to STDOUT
          faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
        end
      end
      
      def bulk_post(body, headers = {'Content-Type' => 'application/json'})
        response = http.post do |req|
          req.url '_bulk'
          req.headers = headers
          req.body = body
        end
      end
      
    end
  end
end
