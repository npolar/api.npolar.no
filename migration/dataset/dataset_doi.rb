# encoding: utf-8

# This migration
# * sends DOI XML metadata to datacite.org
# * binds DOI to landing page on https://data.npolar.no/dataset
# * injects a magic data link (to the auto-zip of all uploaded files)
# * forces dataset.attachments to match actual filenames in the hashi file api
# * creates/updates readme.txt and md5sum.txt
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

  @@people = JSON.parse open("http://api.npolar.no/person/?q=&fields=email,first_name,last_name,currently_employed,events,links&format=json&variant=array&limit=all").read

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

  def self.publicationYear(d)
    DateTime.parse(d.released||d.created).year
  end

  def email
    lambda {|d|

      if not d.people?
        d.people = []
      end

      d.people.map! {|p|
        m = @@people.map {|p| Hashie::Mash.new p }.find {|person| person.last_name == p.last_name and person.first_name == p.first_name }
        if m and m.email?
          if not p.email or p.email.nil? or p.email == "" or p.email != m.email

            p.email = m.email
            log.info p.to_json

          end
        end

        p
      }
      d
    }
  end

  def self.doi(d)
    year = publicationYear(d)
    ident = d.id.split("-")[0]
    prefix = ::Metadata::DataciteXml::NPOLAR_DOI_PREFIX
    "#{prefix}/npolar.#{year}.#{ident}"
  end

  # RIS
  # https://data.datacite.org/application/x-research-info-systems/#{d.doi}

  def self.readme_txt d,files
    people = (d.people||[]).map {|p| "#{p.first_name} #{p.last_name}"}.join(", ")
    filenames = files.map {|h| h["filename"]}.sort.join("\n")

    "https://doi.org/#{d.doi}\n\n#{d.title}

Authors: #{people}\n\n

Files:\n#{filenames}\n

      ".encode(crlf_newline: true)
  end

  def self.md5sum_txt files
    files.map {|f| f["md5sum"] +" "+ f["filename"] }.join("\n")
  end

  def model
    Hashie::Mash.new #Metadata::Dataset.new [real model disabled because of very slow migration with XML schema validation...]
  end

  def migrations
    [email,hashi,data_link,doi]
  end

  def hashi
    lambda {|d|

      d.title = d.title.strip
      begin

        r = request("GET", _file_base_uri(d.id))
        hashi = JSON.parse r.body

        if r.code.to_i == 200 and hashi.key? "files"
          attachment_filenames = (d.attachments||[]).map {|a| a["filename"]}
          hashi_filenames = hashi["files"].map {|h| h["filename"]}

          # Make sure that links in dataset.attachments matches actual filenames in the hashi file api
          # Notice: if there's exactly 1 attachment pointing to the hashi base uri
          # => IGNORE; this means that we do not want to expose the magic _all link (too many files/too large dataset)
          if d.attachments? and d.attachments.size == 1 and d.attachments[0].href = _file_base_uri(d.id)
            # NOOP: IGNORE
          elsif attachment_filenames.sort.to_json != hashi_filenames.sort.to_json
            log.error "#{d.id} linked filenames in dataset attachments != file api filenames \"#{d.title}\""
            log.error "#{d.id} dataset attachments count: #{attachment_filenames.size}, file api filename count: #{hashi_filenames.size}"
            #  hashi: {"filename":"","content_type":"","id":"","file_size":407014,"md5sum":"","modified":"2016-12-16T11:14:25Z","url":""}
            d.attachments = hashi["files"].map {|h| { filename: h["filename"], href: h["url"], type: h["content_type"] } }
            log.info "Setting file attachments to: "+d.attachments.map {|f| f.filename }.to_json
          end

          # Protect / unprotect
          if hashi["files"].length > 0 and d.released? and d.released =~ /^[0-9]{4}/

            released = DateTime.parse(d.released)
            now = DateTime.now
            #diff = (released > now) ? (released-now).to_i : (now-released).to_i

            if now+1 > released

              restricted_files = hashi["files"].reject {|f|
                f["filename"] == "readme.txt" or f["filename"] == "md5sum.txt"
              }.select {|f|
                f.key? "restricted" and f["restricted"] == true
              }.map {|f| f["filename"] }

              if restricted_files.any?
                log.info "#{d.id} released on #{d.released}, unprotecting uploaded files"
                unprotect_released_files hashi["files"]
              end
              # @todo mail_release_annoucement d

            else

              all_restricted = hashi["files"].reject {|f|
                f["filename"] == "readme.txt" or f["filename"] == "md5sum.txt"
              }.all? {|f|
                f.key? "restricted" and f["restricted"] == true
              }
              if not all_restricted
                log.warn "#{d.id} has uploaded unprotected files, but the dataset is in embargo in #{(released - DateTime.now).to_i} days until #{released.to_date} (\"#{d.title}\"), protecting the files now"
                protect_unreleased_files hashi["files"]
              end


            end
          end # No files or no released date

        else # No hashi files

          if d.attachments? and d.attachments.any?
            # Attachments and still no files in hashi? (this should not happen tm)
            log.error "#{d.id} MISSING files: #{d.attachments.to_json} [Hashi HTTP status: #{r.code}]"
            #d.attachments = []
          end
        end

      rescue => e
        log.error e
      end
      d
    }
  end

  #def readme
  #  lambda {|d|
  #  # If doi and create readme.txt and md5sum.txt if missing
  #        if d.doi?
  #          has_readme_txt = hashi_filenames.find {|f| f=~ /^readme\.txt$/i }
  #          if not has_readme_txt # in theory this should be run after doi creation, but then hashi would need to be called again...
  #            # r = save_hashi(d.id, 'readme.txt', self.class.readme_txt(d, hashi["files"]))
  #            # log.info r
  #          else
  #            del = _file_base_uri(d.id)+"/readme.txt"
  #            log.info "npolar-api -X   DELETE #{del}"
  #          end
  #        end
  #    d
  #  }
  #end

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

      doi = self.class.doi(d) # remember: a different doi may be registered for various reasons, see line #240
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

          if not d.doi.nil?
            #if d.doi != doi
            #   # Not harmful as long as d.doi == doi_identifier
            #  log.warn "Dataset: #{d.doi} Datacite: #{doi_identifier} - different from auto-generated DOI #{doi}"
            #end
            if d.doi != doi_identifier
              log.error "Dataset DOI #{d.doi} is different from the registered DOI #{doi_identifier}"
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
        cand = true
        if cand # if data is released in a month (or there is at least 1 attachment)
          #begin

            url = "https://data.npolar.no/dataset/#{d.id}"
            newkernel = ::Metadata::DataciteXml.kernel(d, d.doi||doi) # Using d.doi - the DOI inside the dataset (in case it's different from auto-generated doi)
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
              log.info "[NEW] #{doi} -> #{url} #{d.title}"
              if @@really
                log.info xml
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

  def authors d
    authors = (d.people||[]).select {|p| p.roles.include? "author"}.map {|p| p.last_name+", "+p.first_name }
    if not authors.any?
      authors = (d.organisations||[]).select {|o| o.roles.include? "author"}.map {|o| "#{o.name} (#{o.id})" }
    end
    authors
  end


  def save_hashi id,filename,str
    uri = _file_base_uri(id)+"/"+filename
    if @@really
      log.info "Saving #{uri}"
      request("POST", uri, str)
    else
      log.debug "Not really, so NOT saving #{uri}"
    end
  end

  # run by #hashi when the release date is set to the future ie dataset is under embargo
  def protect_unreleased_files files
    protect = files.reject {|f|
      f["filename"] == 'readme.txt' or f["filename"] == 'md5sum.txt'
    }.select {|f|
      not f.key? "restricted" or f["restricted"] == false
    }

    if protect.any? and @@really
      protect.each do |f|
        uri = f["url"]+"?restricted=true"
        log.info "Protecting #{f["filename"]}:\nPUT #{uri}"
        r = request("PUT", uri, "")
        log.info r
      end
    end
  end

  def unprotect_released_files files
    protected = files.select {|f| f.key?("restricted") and f["restricted"] == true }
    if protected.any? and @@really
      protected.each do |f|
        uri = f["url"]+"?restricted=false"
        log.info "Unlocking #{f["filename"]}:\nPUT #{uri}"
        r = request("PUT", uri, "")
        log.info r
      end
    end
  end

  def is_released? d
    if d.id == "881dbd20-fffc-4b9b-8b25-b417b3a1fc28"
      return true
    end

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
    d.summary? and d.summary.strip.length > 0 and d.summary !~ /^missing$/i
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

    new = {
      doi: d.doi,
      title: d.title,
      publicationYear: self.class.publicationYear(d),
      authors: authors,
      summary: d.summary
    }
    was = {
      doi: k.xpath('//datacite:identifier[@identifierType = "DOI"]', NS).first.text,
      title: k.xpath("//datacite:title[@xml:lang='en']",NS).first.text,
      publicationYear: k.xpath("//datacite:publicationYear",NS).first.text,
      authors: k.xpath("//datacite:creatorName",NS).map {|c| c.text },
      summary: k.xpath("//datacite:description[@xml:lang='en' and @descriptionType='Abstract']",NS).first.text
    }
    # @todo More stuff to check
    #<publisher>npolar.no</publisher>
    #<dates><date dateType="Available">2016-11-21T01:00:00.000Z</date>
    #licences
    if (new.to_json != was.to_json)
      if new[:doi] != was[:doi]
        raise "DOI changed for #{d.id} to: #{new[:doi]} was: #{was[:doi]}"
      end
    end
    (new.to_json != was.to_json)
  end

  def request(method, path, body="", headers={"Content-Type"=>"application/json"}, credentials=[ ENV["NPOLAR_API_USERNAME"], ENV["NPOLAR_API_PASSWORD"] ])
    uri = URI.parse(path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = case method.upcase
    when "GET"
      Net::HTTP::Get.new(uri.request_uri)
    when "POST"
      Net::HTTP::Post.new(uri.request_uri)
    when "PUT"
      Net::HTTP::Put.new(uri.request_uri)
    when "DELETE"
      Net::HTTP::Delete.new(uri.request_uri)
    end

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
