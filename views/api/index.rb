module Views
  module Api  
    class Index < Npolar::Mustache::JsonView

      def initialize
        @hash = { "_id" => "api_index",
          :workspaces => Npolar::Api.workspaces.map {|w| {:href => w, :title => w }},
          :title => "api.<a title=\"Norwegian Polar Institute\" href=\"http://npolar.no\">npolar.no</a>",
          :sections => [{ :section => '<section id="welcome">
<p>You&apos;ve reached the <a href="http://npolar.no">Norwegian Polar Institute</a>&apos;s <strong>searchable data store</strong>,
a <a href="http://en.wikipedia.org/wiki/Representational_state_transfer">REST</a>-style web <a href="http://en.wikipedia.org/wiki/Application_programming_interface">API</a>.
</p>

<p><a href="https://github.com/npolar/api.npolar.no">Source</a> is on <a href="https://github.com/">GitHub</a>, see the project <a href="https://github.com/npolar/api.npolar.no/blob/master/README.md#readme">README</a> for more information.</p>

</section>'}],
        }

      end
  
      def data
        { "workspaces" => ::Npolar::Api.workspaces.map {|w| "#{w}"} }
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