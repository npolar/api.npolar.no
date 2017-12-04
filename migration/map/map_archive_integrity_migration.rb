# # $ ./bin/npolar-api-migrator /map/archive ::MapArchiveIntegrityMigration --really=false > /dev/null
# require "digest/md5"
# require "open-uri"
# require "hashie/mash"
# require "fileutils"
# require "base64"
# require "bundler/setup"
#
# class MapArchiveIntegrityMigration
#
#   @@c = 0
#   @@username = ENV["NPOLAR_API_USERNAME"]||""
#   @@password = ENV["NPOLAR_API_PASSWORD"]||""
#   @@really = (ARGV[2] =~ /^(--really|--really=true)$/) != nil ? true : false
#   @@archive = "/mnt/datasets/api.npolar.no/_file/map/archive"
#   @@imagefile_integrity_storage = "/mnt/datasets/api.npolar.no/_file-integrity/map/archive"
#   sha384_sums_filename = "/mnt/datasets/api.npolar.no/_file-integrity/map-archive-sha384sums.txt"
#   #sha384_sums_filename = @@imagefile_integrity_storage+"/sha384sums-#{DateTime.now.iso8601.split("T")[0]}.txt"
#   if File.exists? sha384_sums_filename
#     #FileUtils.rm sha384_sums_filename
#   end
#   @@sha384_sums = File.open(sha384_sums_filename, "a")
#   attr_accessor :log
#
#   def self.imagemagick_identify filename, log
#     cmd = "identify -verbose -units PixelsPerInch \"#{filename}\""
#     `#{cmd}`.strip
#   end
#
#   # sri_integrity == Digest of file content, base64-encoded, prefixed by hash function plus dash
#   # like: "sha384-N0pNMrwL3jCwSnu7tSxwtBdyxd8JeazaabW+RtWab/hR7P03d6tW9aFsHJWuVdhL"
#   # https://www.w3.org/TR/SRI/
#   # https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity
#   def self.sri_integrity filename, dgst_algo="sha384"
#     cmd = "openssl dgst -#{dgst_algo} -binary \"#{filename}\" | openssl base64 -A"
#     digest =`#{cmd}`.strip
#     "#{dgst_algo}-#{digest}"
#   end
#
#   # Thanks https://stackoverflow.com/questions/18923515/why-is-hex-base64-so-different-from-base64-hex-using-pack-and-unpack
#   def self.base64_to_hex s
#     s.unpack("m0").first.unpack("H*").first
#   end
#
#   def self.file_metadata identify_text, d, log
#     metadata = {}
#     identify_text.split("\n").map {|l| l.split(":").map {|v| v.strip } }.select {|k,v|
#       k =~ /(Image|Geometry|Resolution|Mime type)/
#     }.each do |k,v|
#       k = k.downcase
#       if k == "geometry"
#         g = v.gsub("+0+0", "")
#         w,h = g.split("x")
#         metadata["width"] = w.to_i
#         metadata["height"] = h.to_i
#       end
#       if k == "resolution"
#         metadata["ppi"] = v.split("x")[0].to_f.round(0).to_i
#       end
#       if k == "mime type"
#         metadata["type"] = v
#       end
#       if k == "image"
#         metadata["filename"] = File.basename(v)
#         metadata["path"] = v
#       end
#     end
#
#     file = (d.files||[]).find {|f| f.filename == metadata["filename"] }
#     if file.nil?
#       log.warn "No file: #{metadata.to_json}"
#     end
#     w_mm = nil
#     h_mm = nil
#     if metadata["ppi"].nil? or metadata["ppi"] == 0
#       #log.info "No resolution: #{metadata.to_json}"
#     elsif metadata["width"].nil? or metadata["width"] == 0 or metadata["height"] == 0
#       log.warn "No width/height: #{metadata.to_json}"
#     else
#       w_mm = (25.4*metadata["width"]/metadata["ppi"]).to_i # pixels per inch; 25.4 mm == 1"
#       h_mm = (25.4*metadata["height"]/metadata["ppi"]).to_i
#       dim = "#{w_mm} * #{h_mm} mm"
#       #log.info "#{dim} [#{metadata["width"]} * #{metadata["height"]}] @#{metadata["ppi"]} PPI"
#     end
#     Hashie::Mash.new metadata
#   end
#
#   def model
#     MapArchive.new
#   end
#
#   def migrations
#     [basics,fix_lang_and_country,rights_expiration, hashi, image_metadata]
#   end
#
#   def basics
#     lambda {|d|
#       # set year to 1900 if null or 0
#       if d.publication? and (not d.publication.year? or d.publication.year.nil? or d.publication.year == 0)
#         d.publication[:year] = 1900
#         if not d.comments?
#           d.comments = []
#         end
#         d.comments.reject! {|c| not c.key? :comment }
#         d.comments += [{"comment": "Ukjent år", "lang": "nn" }, {"comment": "Year unknown", "lang": "en" }]
#         d.comments.uniq!
#         log.info d.comments.to_json
#       end
#       if not d.restricted? or not [true,false].include? d.restricted
#         d.restricted = false
#       end
#       if d.files? and d.files.any?
#
#         # Warn of multiplicates, typically created by convert when TIFFs contain 8 russian doll style versions of the image
#         oops = d.files.select {|f| f.filename =~ /-[1-9]\.png$/ }.map {|f| [f.uri,f.filename] }
#         if oops.size > 1
#           log.warn oops.to_json
#         end
#
#         d.files.map! {|f|
#
#           # Fix bad resolution
#           if f.ppi? and (0 == f.ppi % 254)
#             was = f.ppi
#             f.ppi = (was/2.54).round(0).to_i
#
#             if was != f.ppi
#               log.warn "#{f.ppi} <- #{was}"
#             end
#           end
#
#           if f.hash?
#             f.delete :hash
#           end
#           if f.rel?
#             f.delete :rel
#           end
#
#           # Lock/unlock files
#           if d.restricted == false
#             if f.restricted != false
#               f.restricted = false
#               #unlock_file f
#             end
#           end
#           if d.restricted == true
#             if f.restricted != true
#               f.restricted = true
#               #lock_file f
#             end
#           end
#           f
#         }
#       end
#       d
#     }
#   end
#
#   # Set files array with data from the hashi _file server,
#   # but do not nuke integrity or other data in the process
#   def hashi
#     lambda {|d|
#
#       uri = "https://api.npolar.no/map/archive/#{d.id}/_file/"
#
#       if not d.files?
#         d.files = []
#       end
#
#       begin
#         hashi = JSON.load(open(uri, { http_basic_authentication: [@@username,@@password]}))
#         if hashi.key? "files" and hashi["files"].length > 0
#           hashi_files = hashi["files"].map {|h|
#             h = Hashie::Mash.new(h)
#             Hashie::Mash.new({ uri: h.url,
#               filename: h.filename,
#               type: h.content_type,
#               length: h.file_size.to_i,
#               modified: h.modified,
#               restricted: d.restricted.nil? ? false : d.restricted
#             })
#           }
#           map_files_cmp = d.files.map {|f| { filename: f.filename, length: f["length"] } }
#           hashi_files_cmp = hashi_files.map {|h| { filename: h[:filename], length: h[:length] } }
#           if hashi_files_cmp != map_files_cmp
#             log.error "#{d.id} file metadata mismatch: #{map_files_cmp.size} vs. #{hashi_files_cmp.size}"
#             log.error "map: #{map_files_cmp.to_json} hashi: #{hashi_files_cmp.to_json}"
#
#             newfiles = hashi_files.map {|hf|
#               existing = d.files.find {|f| f.filename == hf[:filename] }
#               if (existing.is_a? Hash)
#                 hf = hf.merge(existing) # FIXME @todo file type should also be kept if different as hashi is often wrong
#                 log.warn "Merged in existing metadata: #{hf.to_json}"
#               end
#               hf
#             }
#             d.files = newfiles
#             log.info d.files.to_json
#           end
#         end
#       rescue => e
#         log.error e
#       end
#       if d.files? and d.files == []
#         d.delete :files
#       end
#       d
#     }
#   end
#
#   # Set SHA-384 integrity hash, and also: width, height, resolution (ppi)
#   # The image metadata is stored on disk in
#   def image_metadata
#     lambda {|d|
#       @@c += 1
#       if not Dir.exists? @@archive
#         raise "Cannot access #{@@archive}"
#         return d
#       end
#       if d.files? and d.files.any?
#         #log.info "[#{@@c}] #{d.id} #{d.title}"
#         d.files.map! {|f|
#           imagepath = "#{@@archive}/#{d.id}/#{f.filename}"
#           restricted_imagepath = "#{@@archive}/restricted/#{d.id}/#{f.filename}"
#
#           if not File.exists?(imagepath) and File.exists?(restricted_imagepath)
#             imagepath = restricted_imagepath
#             #log.warn "Map image is open access but file stored under restricted"
#           end
#
#           if File.exists? imagepath
#             basename = File.basename imagepath
#
#             # IMAGEMAGICK IDENTIFY
#             imagemagick_identify_filename = "#{@@imagefile_integrity_storage}/#{d.id}/#{basename}-identify.txt"
#             if File.exists? imagemagick_identify_filename
#               identify_text = File.read imagemagick_identify_filename
#               filename_in_identify_file = identify_text.split("\n").first.split("Image: ").last.strip
#               # sanity check filename_in_identify_file against imegepath
#               if filename_in_identify_file.gsub("restricted/", "") != imagepath.gsub("restricted/", "")
#                 raise "Bad identify cache: #{imagemagick_identify_filename} [filename: #{imagepath}]"
#               end
#
#               # Resolution fixes propagated to the identify storage
#               # Uncomment on demand
#               # meta = self.class.file_metadata identify_text, d, log
#               # if meta.ppi != f.ppi
#               #   log.info "cache: #{meta.ppi} api: #{f.ppi}"
#               #   log.info imagemagick_identify_filename
#               #   identify_text.gsub!(/Resolution: .+$/, "Resolution: #{f.ppi}x#{f.ppi}")
#               #   identify_text.gsub!(/Print size: .+$/, "Print size: ")
#               #   log.info imagemagick_identify_filename
#               #   File.write imagemagick_identify_filename, identify_text
#               # end
#
#             else
#               identify_text = self.class.imagemagick_identify imagepath, log
#               imagemagick_identify_dirname = File.dirname imagemagick_identify_filename
#               FileUtils.mkdir_p imagemagick_identify_dirname
#               File.write imagemagick_identify_filename, identify_text
#             end
#             # EXTRACT METADATA
#             m = self.class.file_metadata identify_text, d, log
#
#             if f[:length].nil? or f[:length].to_i == 0
#               f[:length] = File.size(imagepath)
#             end
#             if f[:width].nil? or f[:width].to_i == 0 and not m[:width].nil?
#               f[:width] = m[:width]
#             end
#             if f[:height].nil? or f[:height].to_i == 0 and not m[:height].nil?
#               f[:height] = m[:height]
#             end
#             if f[:ppi].nil? and not m[:ppi].nil?
#               f[:ppi] = m[:ppi]
#             end
#
#             # SET INTEGRITY (only if missing)
#             integrity_filename = "#{@@imagefile_integrity_storage}/#{d.id}/#{basename}-integrity.txt"
#             if f.integrity.to_s == "" or f.integrity =~ /^md(s)?5[:-]/
#               if f.integrity =~ /md(s)?5[-:]/ and not f.integrity =~ /sha[235]-/
#                 f.integrity = ""
#               end
#
#               if File.exists? integrity_filename
#                 f.integrity = File.read integrity_filename
#               else
#                 f.integrity = self.class.sri_integrity(imagepath, "sha384")
#                 File.write integrity_filename, f.integrity
#                 log.info f.integrity
#               end
#
#             else # integrity is already set
#
#               if not File.exists? integrity_filename
#                 recalc_sha384 = self.class.sri_integrity(imagepath, "sha384")
#                 File.write integrity_filename, recalc_sha384
#               else
#                 # File size changed? recheck integrity
#                 if f[:length] != File.size(imagepath)
#                   if f.integrity != File.read(integrity_filename)
#                     #recalc_sha384 = self.class.sri_integrity(imagepath, "sha384")
#                     log.fatal "SHA-384 hash changed for #{imagepath} from #{f.integrity}"
#                   end
#                 end
#               end
#             end
#             b64 = f.integrity.split("-")[1]
#             hexdigest = self.class.base64_to_hex(b64)
#             r = d.restricted == true ? "restricted/" : "" # fixme this sometimes leads to barf when in wrong bin
#             @@sha384_sums << "#{hexdigest}  #{r}#{d.id}/#{basename}\n"
#             #log.info f.to_json
#
#           else
#             log.warn "Missing: #{f.filename} tried: #{imagepath}"
#           end
#           f
#         }
#       else
#         log.info "No files: #{d.id} #{d.title}"
#       end
#       d
#     }
#   end
#
#   def fix_lang_and_country
#     lambda {|d|
#
#       if d.publication? and d.publication.languages?
#         was = d.publication.languages
#         d.publication.languages.map! {|l|
#           l = l.downcase
#           if l =~  /nynorsk/
#             l = "nn"
#           elsif l =~ /bokmål/
#             l = "nb"
#           elsif l =~ /norsk/
#             l = "no"
#           end
#           l
#         }
#         if was != d.publication.languages
#           log.info was.to_json
#         end
#       end
#
#       summaries = (d.summaries||[]).select {|s| s.lang !~ /^[a-z]{2}$/ }
#       if summaries.any?
#         d.summaries = summaries.map {|s|
#           s.lang = s.lang.downcase
#           if s.lang =~ /nynorsk/
#             s.lang = "nn"
#           end
#           s
#         }
#         log.info d.summaries.to_json
#       end
#
#       comments = (d.comments||[]).select {|s| s.lang !~ /^[a-z]{2}$/ }
#       if comments.any?
#         d.comments = comments.map {|s|
#           s.lang = s.lang.downcase
#           if s.lang =~ /nynorsk/
#             s.lang = "nn"
#           end
#           s
#         }
#         log.info d.comments.to_json
#       end
#
#       if d.publication? and not d.publication.country.nil? and d.publication.country !~ /^[A-Z]{2}$/
#         log.warn "No publication country or bad code: #{d.id} #{d.publication.country.to_json}"
#       end
#
#       if d.publication? and not d.publication.country.nil? and d.publication.country == "EN"
#         d.publication.country = "GB"
#       end
#       d
#
#     }
#   end
#
#   # See https://en.wikipedia.org/wiki/List_of_countries%27_copyright_lengths
#   def rights_expiration
#     lambda {|d|
#       @@c += 1
#       #log.info @@c
#       if true #not d.rightsExpire? or d.rightsExpire =~ /^2100-01-01/
#         if d.publication? and d.publication.year? and d.publication.year > 0
#           wait = 70
#           if d.publication.country == "US"
#             wait = 70
#           elsif d.publication.country == "CA"
#             wait = 50
#           end
#           rightsExpire = Date.new(wait + 1 + d.publication.year).iso8601
#           if rightsExpire != d.rightsExpire
#             d.rightsExpire = rightsExpire
#             log.info "Rights expire: #{d.rightsExpire} <- published #{d.publication.year} +#{wait} years for #{d.publication.country}"
#           end
#         else
#           if not d.publication.year? or d.publication.year == 1900
#             d.rightsExpire = Date.new(2000).iso8601
#             log.info "Year 1900, setting expire to #{d.rightsExpire} #{d.title} [#{d.publication.year}] #{d.license}"
#           end
#         end
#       end
#
#       if d.rightsExpire?
#         expire = DateTime.parse(d.rightsExpire)
#         now = DateTime.now
#         if (now > expire)
#           if d.restricted != false
#             log.warn "Rights expired #{d.rightsExpire}, removing protection and setting public domain mark for #{d.id} #{d.title}"
#             d.restricted = false
#           end
#           if not d.license?
#             d.license = "http://creativecommons.org/publicdomain/mark/1.0/"
#           end
#         end
#       end
#
#       d
#     }
#   end
#
#   protected
#
#   # Sets restricted=false
#   def unlock_file file
#     file_set_restricted file, false
#   end
#
#   # Sets restricted=true
#   def lock_file file
#     file_set_restricted file, true
#   end
#
#   def file_set_restricted file,status
#     uri = file.uri+"?restricted=#{status}"
#     log.info "Setting restricted=#{status} for #{file.filename}"
#     `curl -n -XPUT "#{uri}"`
#   end
#
#   # def link_to_sak
#   #   lambda {|d|
#   #     if d.to_s =~ /sak (\d+)/unrestricted
#   #       if not d.links?
#   #         d[:links] = []
#   #       end
#   #
#   #       d.links << { href: "sak/#{$1}", rel: "related" }
#   #       log.info d.links.to_json
#   #
#   #     elsif d.to_s =~ /na[mv]nekomi/ui
#   #       log.warn d.to_s
#   #     end
#   #     d
#   #   }
#   # end
#
# end
#
# # @todo
#
# # protect restricted
#
# # unprotect unrestricted
#
# # link to sak
#
# # Not restricted AND not license (32)
# # http://api.npolar.no/map/archive/?facets=license,restricted&q=&filter-restricted=false&not-license=http://creativecommons.org/publicdomain/mark/1.0/|http://creativecommons.org/licenses/by/4.0/|http://creativecommons.org/publicdomain/zero/1.0/
#
# # role without name?
#
# # Multiple of same archive
#
# # sha384sum: restricted/03bb557e-ebae-5925-bb9d-90a3934a2054/D5_300910.png: No such file or directory
#
#
# # not PPI
# # also http://api.npolar.no/map/archive/?facets=files.ppi&q=&not-files.ppi=1..&fields=files&format=json
# # td https://data.npolar.no/map/archive/40425017-7b1c-43e5-86c0-b8ba011f99fc
