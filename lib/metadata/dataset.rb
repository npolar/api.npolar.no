# encoding: utf-8
require "hashie"
require "date"

module Metadata

  # Npolar dataset (http://api.npolar.no/schema/dataset) model
  #
  # [Features]
  #   * Extends Hashie::Mash for easy method access
  #   * Before and after logic
  #   * Transform to DIF XML Hash (for creating DIF XML)
  #   * Double schema validation (JSON + XML)!
  #
  # [License]
  #   {http://www.gnu.org/licenses/gpl.html GNU General Public License Version 3} (GPLv3)
  #
  # @author Conrad Helgeland
  class Dataset < Hashie::Mash

    include Npolar::Validation::MultiJsonSchemaValidator

    BASE = "http://api.npolar.no/dataset/"

    CC0 = "http://creativecommons.org/publicdomain/zero/1.0/"

    DIF_SCHEMA_URI = "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd"

    JSON_SCHEMA_URI = "http://api.npolar.no/schema/dataset-1"

    JSON_SCHEMAS = ["dataset-1.json"]

    SCHEMA_URI = {
      "dif" =>  DIF_SCHEMA_URI,
      "json" => JSON_SCHEMA_URI,
      "xml" => DIF_SCHEMA_URI
    }

    AVL = "http://lovdata.no/lov/1961-05-12-2"

    class << self
      attr_accessor :formats, :accepts, :base
    end

    # Process storage response (after all HTTP methods)
    # @return lambda
    # See Core#handle and Core#after
    def self.after
      lambda {|request,response|
        if request.post?
          Dataset.after_create(request,response)
        else
          response
        end
      }
    end

    # Process storage response after create (POST)
    # @return response Rack::Response
    def self.after_create(request,response)
      body = response.body.respond_to?(:read) ? response.body.read : response.body.join("")
      datasets = JSON.parse(body)
      datasets = datasets.is_a?(Hash) ? [datasets] : datasets

      datasets = datasets.map {|d|
        dataset = self.new(d)
        dataset = dataset.add_edit_and_alternate_links
        dataset
      }

      body = case datasets.size
        when 1
          datasets[0].to_json
        else
          datasets.to_json
      end
      response.body = StringIO.new(body)
      response

    end

    # Process incoming dataset(s) before storage interaction
    # @return lambda
    # See Core#handle and Core#before
    def self.before
      lambda {|request|
        if request.put? or request.post?
          Dataset.before_save(request)
        else
          request
        end
      }
    end

    # Machine readable data policy aka. adding default information to dataset(s)
    # @return request
    def self.before_save(request)

      body = request.body.respond_to?(:read) ? request.body.read : request.body.join("")

      datasets = JSON.parse(body)
      datasets = datasets.is_a?(Hash) ? [datasets] : datasets

      datasets = datasets.map {|dataset|

        new(dataset).before_save(request)

      }

      body = case datasets.size
        when 1
          datasets[0].to_json
        else
          datasets.to_json
      end

      request.body = body
      request
    end

    # Default licences
    def self.licences
      ["http://creativecommons.org/licenses/by/4.0/"]
    end

    # Not used atm.
    def self.licence_codes
      ["nlod", "cc-by", "cc0"]
    end

    # Accepts
    def self.mimetypes
      ["application/json", "application/xml"]
    end

    # Organisation template for npolar.no
    def self.npolar(roles=["originator", "owner", "publisher", "pointOfContact", "resourceProvider"])
      Hashie::Mash.new({ id: "npolar.no",
        name: "Norwegian Polar Institute",
        email: "data@npolar.no",
        gcmd_short_name: "NO/NPI",
        roles: roles,
        homepage: "http://npolar.no"
      })
    end

    # Default rights (human readable usage requirements)
    def self.rights(dataset=nil)
      ""
      #if dataset.publicdomain?
      #  "Public domain."
      #elsif dataset.open?
      #  "Open data: Free to reuse if attributed to the Norwegian Polar Institute."
      #elsif dataset.åvl?
      #  "Protected by 'åndsverkloven': https://lovdata.no/lov/1961-05-12-2"
      #end
    end

    # Åndsverksloven?
    def åvl?
      (licences||[]).select {|l| l == AVL }.size > 0
    end

    # Accept schemas
    def self.schemas
      [schema_uri("json"), schema_uri("xml")]
    end

    # Schema URI for format
    def self.schema_uri(format="json")
      if SCHEMA_URI.key? format
        SCHEMA_URI[format]
      else
        raise ArgumentError, "Unknown schema format: \"#{format}\""
      end
    end


    # Before save: Add information to dataset
    # See self.before_save
    def before_save(request=nil)
        username = request.nil? ? "anonymous" : request.username

        self[:collection] = "dataset"

        if not progress?
          self[:progress] = "planned"
        end

        if not lang?
          self[:lang] = "en"
        end

        # @todo !? Force to draft if missing title,\ and licences?
        # self[:draft] = "yes"
        #end

        if not title?
          self[:title] = "Dataset created by #{username} at #{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")}"
        end

        if not licences? or licences.none?
          self[:licences] = self.class.licences
        end

        if licences.include? CC0
          self[:licences] = [CC0]
        elsif licences.include? AVL
          self[:licences] = [AVL]
        end

        if not rights? or rights.nil? or rights == ""
          self[:rights] = self.class.rights(self)
        end

        if not organisations? or organisations.none?
          self[:organisations] = [self.class.npolar]
        end

        if data? and not resourceProvider?
          #self[:organisations] << self.class.npolar(["resourceProvider"])
        end

        if not publisher?
          #self[:organisations] << self.class.npolar(["publisher"])
        end

        if data? #and restricted? and not (true == restricted)
          if not released? and open?
            self[:released] = created
          end
        end

        if not topics? or topics.none?
          self[:topics] = ["other"]
        end

        if not schema?
          self[:schema] = self.class.schema_uri
        end

        #if placenames? and placenames.area etc Svalbard (150) Antarctica (3) Alaska (1) Southern Ocean (1)
        #  # sets << arctic
        #end
        #    # @todo Set arctic/antarctic based on coverage.latitude !?

        before_valid

        deduplicate_links

        #deduplicate_people

        #deduplicate_organisations

        add_edit_and_alternate_links

        # sets from topics
        # @todo oceanography => force "marine"

        self
    end
    alias :empty :before_save

    # Manipulates dataset before validation
    # @override MultiJsonSchemaValidator
    def before_valid

      if activity?
        activity.map {|a|
          if a.start? and a.start == ""
            a.delete :start
          end
          if a.stop? and a.stop == ""
            a.delete :stop
          end
          a
        }
      end

      if coverage?
        coverage.map {|c|
          if c.north?
            c.north = c.north.to_f
          end
          if c.south?
            c.south = c.south.to_f
          end
          if c.east?
            c.east = c.east.to_f
          end
          if c.west?
            c.west = c.west.to_f
          end
        }
      end
      self

    end

    # Data link?
    def data?
      (links||[]).select {|link| link.rel == "data" }.size > 0
    end

    # Free data?
    def free?
      open? or publicdomain?
    end

    # Open data?
    def open?
      nlod = /data.norge.no\/nlod/
      ccby = /creativecommons.org\/licenses\/by/
      odc = /opendatacommons.org\/licenses\/by/
      (licences||[]).select {|l| l =~ /#{nlod}|#{ccby}|#{odc}/ }.size > 0
    end

    # Public domain? (CC0?)
    def cc0?
      cc0 = /creativecommons.org\/publicdomain\/zero/
      (licences||[]).select {|l| l =~ cc0 }.size > 0
    end
    alias :publicdomain? :cc0?

    def authors
      (people||[]).select {|o| o.roles.include? "author" or  o.roles.include? "principalInvestigator" }
    end

    def owners
      (organisations||[]).select {|o| o.roles.include? "owner"}
    end

    def updated_time
      DateTime.parse(updated).to_time
    end

    def to_dif_hash
      DifHashifier.new(self).to_hash
    end

    def pointOfContact
      (people||[]+organisations||[]).select {|entity| entity.roles.include? "pointOfContact"}
    end

    def to_dif
      dif = ::Gcmd::Dif.new( to_dif_hash )
      dif.to_xml.gsub(/\<\?xml.*\?\>/, "")
    end

    #def to_oai_dc
    #  xml = Builder::XmlMarkup.new
    #  xml.tag!("oai_dc:dc",
    #    'xmlns:oai_dc' => "http://www.openarchives.org/OAI/2.0/oai_dc/",
    #    'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
    #    'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
    #    'xsi:schemaLocation' =>
    #      %{http://www.openarchives.org/OAI/2.0/oai_dc/
    #        http://www.openarchives.org/OAI/2.0/oai_dc.xsd}) do
    #      xml.tag!('oai_dc:title', title)
    #      xml.tag!('oai_dc:description', summary)
    #      xml.tag!('oai_dc:creator', people.select{|p|p.role=="principalInvestigator"}.map {|i| i.first_name + " " + i.last_name}.join(", "))
    #      tags||[].each do |tag|
    #        xml.tag!('oai_dc:subject', tag)
    #      end
    #  end
    #  xml.target!
    #end

    def uri(id)
      self.class.uri + id
    end

    # A href can only exist once for the same rel
    def deduplicate_links
      self[:links] = (links||[]).uniq
    end

    # Uniqify people (see #before_save)
    def deduplicate_people
      unique_people = (people||[]).map {|p| [p.first_name, p.last_name]}.uniq
      self[:people] = unique_people.map {|first_name, last_name |
        persons = people.select {|p| first_name == p.first_name and last_name == p.last_name }
        person = persons[0]
        # Not future proof
        {
          "id" => person.id,
          "first_name" => first_name,
          "last_name" => last_name,
          "roles" => persons.map {|p| p.roles }.flatten.uniq,
          "email" => person.email,
          "organisation" => person.organisation
        }
      }
      self
    end

    # Uniqify organisations (see #before_save)
    def deduplicate_organisations
      unique_organisations = (organisations||[]).map {|o| o.id }.uniq

      self[:organisations] = unique_organisations.map {|id|
          same_id = (organisations||[]).select {|o| o.id == id }

          roles = same_id.map {|o| o.roles }.flatten.uniq
          links = same_id.map {|o| o.links }.flatten.uniq
          org = same_id[0]
          org[:roles] = roles
          org[:links] = links
          org

        }
      self
    end

    # Add links for "edit" (application/json) and alternate formats
    def add_edit_and_alternate_links
      api = ENV["NPOLAR_API"] ||= "https://api.npolar.no"

      self[:links] = links||[]

      if id? # => These links are not added on POST

        # edit  ("application/json")
        if links.select {|link| link.rel=="edit" and link.type == "application/json"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "#{api.gsub(/^http[:]/, "https:")}/dataset/#{id}",
            "rel" => "edit", "title" => "JSON (edit URI)", "type" => "application/json" })
        end

        # DIF XML
        if links.select {|link| link.rel=="alternate" and link.type == "application/xml"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "#{api}/dataset/#{id}.xml",
            "rel" => "alternate", "title" => "DIF XML", "type" => "application/xml"})
        end

        # DIF XML
        if links.select {|link| link.rel=="alternate" and link.type == "application/vnd.iso.19139+xml"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "#{api}/dataset/#{id}.iso",
            "rel" => "alternate", "title" => "ISO 19139 XML", "type" => "application/vnd.iso.19139+xml"})
        end

        # Atom XML
        if links.select {|link| link.rel=="alternate" and link.type == "application/atom+xml"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "#{api}/dataset/#{id}.atom",
            "rel" => "alternate", "title" => "Atom entry XML", "type" => "application/atom+xml"})
        end

        # html
        if links.select {|link| link.rel=="alternate" and link.type == "text/html"}.size == 0
          self[:links] << Hashie::Mash.new({ "href" => "http://data.npolar.no/dataset/#{id}",
            "rel" => "alternate", "title" => "HTML", "type" => "text/html" })
        end
      end

      self

    end

    # @override MultiJsonSchemaValidator
    def schemas
      JSON_SCHEMAS
    end

    # Validate using Dataset JSON schema *and* DIF XML schema
    # def valid?(d=nil)
    #   [super,valid_dif?].all? {|v| v == true }
    # end

    def valid_dif?
      dif = Gcmd::Dif.new(to_dif_hash)
      v = dif.valid?
      #p dif.errors # really slow
      if v == false
        if @errors.nil?
          @errors = []
        end
        @errors += dif.errors
      end
      v
    end



  end

end
