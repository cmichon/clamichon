%w[irb/completion sequel].map &method(:require)
DB = Sequel.connect ENV['DATABASE_URL']
require_relative 'models'

# vim:et:ff=unix:sw=2:ts=2:
