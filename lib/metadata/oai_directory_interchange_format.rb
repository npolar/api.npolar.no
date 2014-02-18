module Metadata

  # Simple implementation of the Directory Interchange Format
  class OaiDirectoryInterchangeFormat < ::OAI::Provider::Metadata::Format

    def initialize
      @prefix = "dif"
      @schema = "http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd"
      @namespace = "http://gcmd.nasa.gov/Aboutus/xml/dif/"
      @element_namespace = 'dif'
      @fields = [ :entry_id, :entry_title, :dataset_citation, :personnel, :discipline, :parameters,
        :iso_topic_category, :keyword, :sensor_name, :source_name, :temporal_coverage,
        :paleo_temporal_coverage, :data_set_progress, :spatial_coverage, :project, :quality,
        :access_constraints, :use_constraints, :data_set_language, :originating_center, :data_center,
        :distrubution, :multimedia_sample, :reference, :summary, :related_url, :parent_dif, :idn_node,
        :originating_metadata_node, :metadata_name, :metadata_version, :dif_creation_date, :last_dif_revision_date,
        :dif_revision_history, :future_dif_review_date, :private, :extended_metadata ]
    end

    def header_specification
      { "xmlns:dif" => "http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/",
        "xsi:schemaLocation" =>
          %{http://gcmd.gsfc.nasa.gov/Aboutus/xml/dif/
            http://gcmd.nasa.gov/Aboutus/xml/dif/dif.xsd}.gsub(/\s+/, " ")
      }
    end

  end
end