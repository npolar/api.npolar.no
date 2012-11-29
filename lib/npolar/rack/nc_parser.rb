require "numru/netcdf"

module Npolar
  module Rack
    class NcParser < Npolar::Rack::Middleware
      
      include NumRu
      
      META = ["station", "cruise", "platform", "ctd"]
      DATA = ["time", "latitude", "longitude", "pressure", "temperature", "salinity", "fluorescence"]
      
      BUFFER_FILE = "/tmp/buffer.nc"
      STORAGE = "/home/dens/storage/oceanography/ctd/"
      
      def condition?(request)
        netcdf?(request)
      end
      
      def handle(request)
        
        if ["PUT", "POST"].include?(request.request_method)
          data = request.body.read
          hash = parse_netcdf( data, request.env['HTTP_LINK'] )
          
          request.env['rack.input'] = StringIO.new( hash.to_json )
          request.env['CONTENT_TYPE'] = "application/json"
          
          return app.call( request.env )
        elsif ["GET"].include?(request.request_method)          
          file = STORAGE + request.id + ".nc"          
          data = File.open(file , "rb"){|io| io.read}          
          return [200, {"Content-Type" => "application/netcdf"}, [data]]
        end     
        
      end
      
      def parse_netcdf(data, metadata)
        create_buffer(BUFFER_FILE, data)        
        nc = NetCDF.new(BUFFER_FILE)
        
        json = {
          "metadata" => metadata
        }
        
        json["date-time"] = nc.var("time").get.to_a.first.to_i.to_s + "-01-01T12:00:00Z"
        
        # Metadata gathering
        
        nc.att_names.each do |attr|
          if META.include?(attr)
            unless nc.att(attr).get.class.to_s == "NArray"
              json[attr] = nc.att(attr).get.to_s
            else
              json[attr] = nc.att(attr).get.to_a.first.to_s
            end          
          end
        end
        
        # Data gathering
        nc.var_names.each do |var|
          if DATA.include?(var)
            json[var] = nc.var(var).get.to_a.map{ |v| v.to_s == "NaN" ? nil : v }
          end
        end
        
        json
      end
      
      def create_buffer(file, data)
        File.open(file, "wb" ) do |tmp|
          tmp.puts data
        end
      end
      
      protected
      
      def netcdf?(request)
        return true if request.format == "nc" or request.content_type =~ /application\/netcdf/  
        false
      end
      
    end
  end
end
