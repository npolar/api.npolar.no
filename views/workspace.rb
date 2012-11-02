# encoding: utf-8
module Views
  class Workspace < Npolar::Mustache::JsonView

    def h1_title
      "<a title=\"api.npolar.no\" href=\"/\">api</a>/#{workspace}"
    end

    def nav
      collections
    end
  end
end