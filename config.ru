require 'sequel'

DB = Sequel.connect ENV['DATABASE_URL']
Sequel.extension :migration
Sequel::Migrator.apply DB,'migrations'

class User < Sequel::Model
end

require './app'

run Sinatra::Application
