require "hashie"

class Project < Hashie::Mash
  include Npolar::Validation::MultiJsonSchemaValidator

  def schemas
    ["project.json"] 
  end

  def before_valid
  
    if start_date? and start_date == ""
      self.delete :start_date
    end
    if end_date? and end_date == ""
      self.delete :end_date
    end
    self

  end
end