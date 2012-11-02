class Gcmd::Index < Views::Workspace

  self.template = Views::Workspace.template

  def initialize
    @hash = { :_id => "gcmd_index",
      :workspace => "gcmd",
    }
  end

  def collections
    ["concept"].map {|c| {:title => c, :href => "/gcmd/#{c}"}}
  end

  def workspace
    self.class.name.split("::")[0].downcase
  end
end