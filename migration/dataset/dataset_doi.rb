# encoding: utf-8

# This migration
# * sends DOI XML metadata to datacite.org
# * binds DOI to landing page
# * injects a magic data link (to the auto-zip of all uploaded files)
# * forces dataset.attachments to match actual filenames in the hashi file api 
# * @todo creates readme.txt and md5sum.txt
# * Releases files when embargo period ends
# * Protects files that are uploaded with a future release date (@todo consider "embargo" as new progress state)
#
# $ ./bin/npolar-api-migrator /dataset ::DatasetDoi --really=false --credentials=$DATACITE_CREDENTIALS --log-level=WARN > /dev/null
require "date"
require "time"
require "json"
require "uri"
require "open-uri"
require_relative "../../lib/metadata/dataset"
require_relative "../../lib/metadata/datacite_xml"
require_relative "../../lib/metadata/datacite_mds"

class DatasetDoi

  attr_accessor :log

  NS = { datacite: "http://datacite.org/schema/kernel-4"}
  
  @@really = (ARGV[2] =~ /^(--really|--really=true)$/) != nil ? true : false
  credentials = []
  if ARGV.find {|a| a=~ /^--credentials=(.+[:].+)/ }
    credentials = $1.split(":")
  end
  ::Metadata::DataciteMds.credentials = credentials
  ::Metadata::DataciteMds.testMode = (@@really == true) ? false : true
  
  def self.dois
    @@dois ||= ::Metadata::DataciteMds.dois
  end

  def self.doi(d)
    year = DateTime.parse(d.released||d.created).year
    ident = d.id.split("-")[0]
    prefix = ::Metadata::DataciteXml::NPOLAR_DOI_PREFIX
    "#{prefix}/npolar.#{year}.#{ident}"
  end

  def model
    Hashie::Mash.new #Metadata::Dataset.new [real model disabled because of very slow migration with XML schema validation...]
  end

  def migrations
    #[hashi,data_link,doi]
    [protect_unreleased_files,unprotect_released_files,data_link,doi]
  end
  
  def protect_unreleased_files # ie when the release date is set to the future ie dataset is under embargo
    lambda {|d|
      
      if d.released and d.released =~ /^[0-9]{4}/
        released = DateTime.parse(d.released)
        if (DateTime.now < released and d.attachments? and d.attachments.any?)
          r = get(_file_base_uri(d.id))
          hashi = JSON.parse r.body
          all_restricted = hashi["files"].all? {|f| f.key? "restricted" and f["restricted"] == true }
          if not all_restricted
            log.warn "#{d.id} has uploaded unprotected files, but the release date is in #{(released - DateTime.now).to_i} days [#{released.to_date}] \"#{d.title}\""
            protect_uris = hashi["files"].select {|f| not f.key? "restricted" or f["restricted"] == false }.map {|f| f["url"] }
            
            if @@really
              protect_uris.each do |uri|
                log.info "Protecting #{uri}"
                put(uri+"?restricted=true", "")
              end
            end
            
            
          end
        end
      end
      d
    }
  end
  
  def unprotect_released_files
    lambda {|d|
      
      if d.released and d.released =~ /^[0-9]{4}/
        released = DateTime.parse(d.released)
        if (DateTime.now+1 > released and d.attachments? and d.attachments.any?)
          r = get(_file_base_uri(d.id))
          hashi = JSON.parse r.body
          protected_uris = hashi["files"].select {|f| f.key?("restricted") and f["restricted"] == true }.map {|f| f["url"] }
          if protected_uris.any?
            log.info "#{d.id} dataset released #{d.released}, unprotecting uploaded files \"#{d.title}\""
            
            if @@really
              protected_uris.each do |uri|
                log.info "Unlocking #{uri}"
                put(uri+"?restricted=false", "")
              end
            end
            
          end
        end
      end
      d
    }
  end

  # Make sure that links in dataset.attachments matches actual filenames in the hashi file api 
  def hashi
    lambda {|d|
      begin

        r = get(_file_base_uri(d.id))
        hashi = JSON.parse r.body

        if hashi.key? "files"
          attachment_filenames = (d.attachments||[]).map {|a| a["filename"]}
          hashi_filenames = hashi["files"].map {|h| h["filename"]}
          #data = (d.links||[]).select {|l| l.rel == "data"}
          if attachment_filenames.sort.to_json != hashi_filenames.sort.to_json
            log.error "#{d.id} linked filenames in dataset attachments != file api filenames \"#{d.title}\""
            log.error "#{d.id} dataset attachments count: #{attachment_filenames.size}, file api filename count: #{hashi_filenames.size}"
            #  hashi: {"filename":"","content_type":"","id":"","file_size":407014,"md5sum":"","modified":"2016-12-16T11:14:25Z","url":""}
            d.attachments = hashi["files"].map {|h| { filename: h["filename"], href: h["url"], type: h["content_type"] } }
            log.info d.attachments.to_json
          end
        else
          # No files in hashi
          if d.attachments? and d.attachments.any?
            log.error "#{d.id} MISSING files: #{d.attachments.to_json}"
          end
        end

      rescue => e
        log.error e
      end
      d
    }
  end

  # Set data link if missing; either from files or from services
  def data_link
    lambda {|d|
      
      if not d.links?
        d.links = []
      end
      
      if d.attachments? and d.attachments.size > 0
        
        if not d.links.any? {|l| l.href =~ /\/_all\// and l.rel == "data" }
          filename = (d.doi.to_s =~ /#{::Metadata::DataciteXml::NPOLAR_DOI_PREFIX}/) ? d.doi.split('/')[1]+'-data' : nil
          href = "#{_file_base_uri(d.id)}/_all/?filename=#{filename}&format=zip"
          type = "application/zip"
          d.links << { rel: "data", href: href, type: type }
        end
        
      else
        #if not d.links.any? {|l| l.rel == "data" } and d.links.any? {|l| l.rel == "service" }
        #  first_service = d.links.select {|l| l.rel == "service" }.first
        #  # @todo force data link when there is a service?
        #end
      end
      
      
      d
    }
  end

  def doi
    lambda {|d|

      doi = self.class.doi(d) # remember: a different doi may be registered for various reasons...
      dataset_is_updated_after_doi = false
      changed = true

      if d.doi? and d.doi =~ /^#{::Metadata::DataciteXml::NPOLAR_DOI_PREFIX}/

        # Get DOI timestamp to detect if metadata is updated
        begin
          r = ::Metadata::DataciteMds.getMetadata(d.doi)
          kernel = Nokogiri::XML(r.body)

          doi_updated = DateTime.parse kernel.xpath('//datacite:date[@dateType = "Updated"]', NS).first.text
          doi_identifier = kernel.xpath('//datacite:identifier[@identifierType = "DOI"]', NS).first.text

          updated = DateTime.parse d.updated
          dataset_is_updated_after_doi = (updated > doi_updated)

          if !d.doi.nil? && d.doi != doi
            if d.doi != doi_identifier
               log.warn "Dataset DOI #{d.doi} is different from the registered DOI #{doi_identifier}"
            end
          end

        rescue => e
          log.fatal e.to_s
        end
        #hdl_api_uri = "http://hdl.handle.net/api/handles/#{d.doi}"
        #r = get(hdl_api_uri)

      end

      if (d.doi.nil? or dataset_is_updated_after_doi) and is_released? d

        if d.doi.nil?
          m = self.class.dois.find {|doi| doi =~ /#{self.class.doi(d)}/}
          if not m.nil?
            d.doi = self.class.doi(d)
            log.warn "#{d.doi} missing in Dataset JSON, but is already a registered DOI"
            # @todo check that DOI destination => URI with d.id (highly unlikely problem)
          end
        end

        released = DateTime.parse(d.released||d.created)
        inamonth = DateTime.now+30
        cand = ((d.attachments? and d.attachments.any?) or (DateTime.now > released) or (released < inamonth))

        if cand # if data is released in a month (or there is at least 1 attachment)
          #begin

            url = "https://data.npolar.no/dataset/#{d.id}"
            newkernel = ::Metadata::DataciteXml.kernel(d, doi)
            xml = newkernel.to_xml

            if self.class.dois.include? d.doi or self.class.dois.include? doi
              
              if dataset_is_updated_after_doi and is_doi_metadata_changed? d,kernel
                log.info "[UPDATING] https://doi.org/#{d.doi} npolar: #{d.updated} datacite: #{doi_updated} \"#{d.title}\""
                ::Metadata::DataciteMds.sendMetadata(xml)
              end

              #else
              #  raise "Duplicate: DOI #{doi} is already registered"
              #end
            else
              log.info "[NEW] #{d.doi} [#{doi}] -> #{url} #{d.title}"
              if @@really
                ::Metadata::DataciteMds.registerDoi(doi, url, xml)
              end
              d.doi = doi
            end
          #rescue => e
          #  log.error "#{d.id} #{doi} "+e.to_json
          #end

        else
          # no cand
          if not d.doi?
            # and no doi
            log.warn "Not considered: #{d.id} \"#{d.title}\""
          end
        end

      end
      d
    }
  end

  protected
  
  def _file_base_uri id
    "https://api.npolar.no/dataset/#{id}/_file"
  end

  def is_released? d

    authors = ((d.people||[]).select {|p| p.roles.include? "author"} + d.organisations.select {|o| o.roles.include? "author"})
    #if authors.none?
    #  log.warn "No authors: #{d.id}"
    #end
    d.released? and d.links? and (d.people? or d.organisations?) and d.licences?
    d.released =~ /^[0-9]{4}/ and # not in future   
    d.links.any? {|l| ["data", "service"].include? l.rel } and
    authors.any? and
    d.organisations.any? {|p| p.roles.include? "publisher"} and
    d.licences.any? and
    d.summary? and d.summary.chomp.length > 0 and d.summary !~ /^missing$/i
  end

  def is_doi_metadata_changed? d,k
    if not k.respond_to? :xpath
      log.warn "No existing kernel provided for #{d.id}"
      return true
    end

    authors = (d.people||[]).select {|p| p.roles.include? "author"}.map {|p| p.last_name+", "+p.first_name }
    if not authors.any?
      authors = (d.organisations||[]).select {|o| o.roles.include? "author"}.map {|o| "#{o.name} (#{o.id})" }
    end

    new = { doi: d.doi,
      title: d.title,
      authors: authors,
      summary: d.summary
    }
    was = {
      doi: k.xpath('//datacite:identifier[@identifierType = "DOI"]', NS).first.text,
      title: k.xpath("//datacite:title[@xml:lang='en']",NS).first.text,
      authors: k.xpath("//datacite:creatorName",NS).map {|c| c.text },
      summary: k.xpath("//datacite:description[@xml:lang='en' and @descriptionType='Abstract']",NS).first.text
    }
    # @todo More stuff to check
    #<publisher>npolar.no</publisher>
    #<publicationYear>2016</publicationYear>
    #<dates><date dateType="Available">2016-11-21T01:00:00.000Z</date>
    #licences
    if (new != was)
      if new[:doi] != was[:doi]
        raise "DOI changed for #{d.id} to: #{new[:doi]} was: #{was[:doi]}"
      end
    end
    (new != was)
  end
  
  def get(uri,headers={},credentials=[ ENV["NPOLAR_API_USERNAME"], ENV["NPOLAR_API_PASSWORD"] ])
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 5000
    http.use_ssl = true if uri.scheme == 'https'
    request = Net::HTTP::Get.new(uri.request_uri)
    if credentials.length == 2
      request.basic_auth credentials[0],credentials[1]
    end
    headers.keys.each do |key|
      request[key] = headers[key]
    end
    response = http.request(request)
    if response.code.to_i >= 300
      raise "GET #{uri}\n#{response.code}\n#{response.body}"
    end
    response
  end
  
  def put(path, body = "", headers={"Content-Type"=>"application/json"}, credentials=[ ENV["NPOLAR_API_USERNAME"], ENV["NPOLAR_API_PASSWORD"] ])
    uri = URI.parse(path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Put.new(uri.request_uri)
    
    if credentials.length == 2
      request.basic_auth credentials[0],credentials[1]
    end
    headers.keys.each do |key|
      request[key] = headers[key]
    end
    request.body = body
    http.request(request)

  end

end

#if not d.summary? or d.summary == "" or d.summary == "MISSING"
#  d.summary = "MISSING"
#  log.warn "No summary: #{d.id} #{d.doi} \"#{d.title}\""
#end