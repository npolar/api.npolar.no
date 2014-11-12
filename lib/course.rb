require "hashie"

class Course < hashie::Mash
     include Npolar::Validation::MultiJsonSchemaValidator

     def schemas
         ["course.json"]
     end

