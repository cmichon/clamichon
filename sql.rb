require 'irb/completion'
require 'sequel'
DB = Sequel.connect ENV['DATABASE_URL']
class User < Sequel::Model ; end
class Check < Sequel::Model ; end
