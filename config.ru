%w[octokit roda sequel].map &method(:require)

DB = Sequel.connect ENV['DATABASE_URL']
Sequel.extension :migration
Sequel::Migrator.apply DB,'migrations'

require_relative 'models'
require_relative 'app'
run App.freeze.app

# vim:et:ff=unix:sw=2:ts=2:
