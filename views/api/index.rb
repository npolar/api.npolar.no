module Views
  module Api  
    class Index < Npolar::Mustache::JsonView

      def initialize
        @hash = { "_id" => "api_index",
          :_rev => "11-7dfa6bc5bbe79996432e49760df7d268",
          :workspaces => [
            {
              :href => "/ecotox",
              :title => "Environmental pollutants"
            },
            {
              :href => "/metadata",
              :title => "Discovery-level metadata"
            },
            #{
            #  :href => "/ocean",
            #  :title => "Oceanography data"
            #},
            {
              :href => "/seaice",
              :title => "Seaice and its physical properties"
            },
            #{
            #  :href => "/tracking",
            #  :title => "Tracking data"
            #}
          ],
          :title => "api.npolar.no"
        }

      end
  
      def data
        { "workspaces" => ::Npolar::Api.workspaces.map {|w| "/#{w}"} }
      end
#
#<dt>Search all documents</dt>
#<dd><a href="/?q=Polar+bear">Search all documents for "Polar bear"</a></dd>
#
#<dt>Limit to a workspace</dt>
#<dd><a href="/seaice/?q=Lance">Search all collections in the "seaice" workspace for "Lance"</a></dd>
#
#<dt>Limit to a collection</dt>
#<dd><a href="/ecotox/report?q=nvh.no">Search Ecotox reports for <cite>nvh.no</cite></a></dd>
#
#<dt>Filter on any attribute</dt>
#<dd><a href="/metadata/dataset?fq=group:seaice&q=*">Metadata for all "seaice" datasets</a></dd>
#
#<dt>Multiple filters</dt>
#<dd><a href="/ecotox/?fq=compound:PCB*&fq=species:Larus+hyperboreus&q=*">All PCB-measurements of glaucous gull</a></dd>
#
#<dt>Geo-search</dt>
#<dd><a href="/?bbox=n,e,s,w&q=*">Bounding box (N,E,S,W)</a></dd>


    end
  end
end