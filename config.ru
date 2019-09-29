require 'sequel'

DB = Sequel.connect ENV['DATABASE_URL']

require './app'

run Sinatra::Application
