module Polarbear
  class Interaction

    def self.facets
      [
      "bear_adult_female_count", "bear_adult_female_death_count", "bear_code", "bear_count", "bear_death_count",
      "bear_death_count_sum", "bear_prior_activity", "bear_species_record", "bear_spray_possession",
      "charge_count", "closest_distance_m",
      #comments
      "cohort", "country", "country_code", "data_quality", "date_quality",
      "datum", "did_bear_attempt_attack", "dog_interaction", "duration", "encounter_group_size", "entry", "entry_status",
      #"event_date",
      "event_month", "event_time", "event_year", "firearm_possession", "food_distance", "food_prep", "food_present", "food_reward", "food_storage",
      "general_activity", "group_type", "habitat_visibility_description", "has_map_point", "human_injury", "human_involvement", "human_prior_activity",
      #"id",
      "information_source",
      #"information_source_desc",
      "initial_distance_m",
      "insert_by",
      #"insert_date",
      "interact_group_size", "last_update_by",
      #"last_update_date",
      #"latitude_dec_deg",
      #"location_description",
      "location_quality", "location_security", "location_source",
      #"longitude_dec_deg",
      "management_action",
      "noise_making",
      "overall_visibility", "overall_visibility_2", "person_ran_from_bear", "place_name", "probable_cause", "probable_responsibility", "property_damage",
      "received_safety", "record_num", "record_type", "site_use_frequency", "time_of_day", "total_group_size", "transportation"]

    end

    def self.to_solr_lambda
      lambda {|doc| # Hash with symbolized keys

      # ids are integers, even negative, record_id are nice, UUID?
 
      t = Time.new(doc[:event_year],doc[:event_month],doc[:event_day])
      isodate = t.strftime("%Y-%m-%d")

      # text, narrative, and comments are searchable, but not stored (because of sensitive/person information)
      text = ""
      doc.each do |k,v|
        text += "#{k} = #{v} |"
      end

      #position_text = 
      
      doc = doc.merge(
        :title => "#{doc[:bear_species_record]} interaction #{isodate} #{doc[:place_name]} #{doc[:country]} (#{doc[:latitude_dec_deg]}N #{doc[:longitude_dec_deg]}E)",
        :text => text
      )
      
    }
    end
  end
end