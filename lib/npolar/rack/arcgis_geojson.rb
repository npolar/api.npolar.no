module Npolar
  module Rack
    # GeoJSON (and TopoJSON) ArCGIS proxy
    # Requires ogr2ogr command from GDAL: http://www.gdal.org/ 
    class ArcGISGeoJSON < Rack::Middleware

      CONFIG = {
        :base => nil # Like "http://geodata.npolar.no/arcgis/rest/services"
      }

      def call(env)
        @request = ::Rack::Request.new(env)
    
        base = config[:base]

        if ["GET", "HEAD"].include? request.request_method # @todo validate against http://geodata.npolar.no/arcgis/rest/services?f=pjson
          # Given path "/inspire3/Samfunn/MapServer/2", construct ogr2ogr command like
          # ogr2ogr -f GeoJSON /dev/stdout "http://geodata.npolar.no/arcgis/rest/services/inspire3/Samfunn/MapServer/2/query?where=1=1&outFields=*&returnGeometry=true&outsr=4326&f=pjson"
          path,format = request.path_info.split(".")
    
          uri = URI.parse "#{base}#{path}/query?where=1=1&outFields=*&returnGeometry=true&outsr=4326&f=pjson"
          ogrcmd = "ogr2ogr -f GeoJSON /dev/stdout \"#{uri}\""
    
          result = geojson = `#{ogrcmd}`
          if result == ""
            return [404, {"Content-Type" => "application/json; charset=utf-8"}, ["ArcGIS service does not exist: #{uri}"]]
          end
          
          begin JSON.parse(result)
            
          rescue
            return [500, {"Content-Type" => "application/json; charset=utf-8"}, ["Not valid JSON from ArcGIS service: #{uri}"]]
          end
        
          if format =~ /^topo(json)$/
            tmp = Tempfile.new("topojson"+request.path_info.gsub(/\//, "_"))
            tmp.write geojson
            result = `topojson #{tmp.path} -p`
            tmp.unlink
          end
          
          return [200, {"Content-Type" => "application/json; charset=utf-8"}, [result]]
    
        end
          
      end
    end
  end

end
