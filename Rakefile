#!rake
#coding: utf-8

require 'rake/clean'
require "rubygems"
require "hoe"

# 1.9.2 and later require explicit relative require
if defined?( require_relative )
	$stderr.puts "Requiring relative lib/hoe/hg..."
	require_relative "lib/hoe/hg"
	$stderr.puts "  require done."
else
	$LOAD_PATH.unshift( 'lib' )
end

Hoe.plugin :doofus, :hg
Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec "hoe-hg" do
  developer "McClain Looney", "m@loonsoft.com"

  self.extra_rdoc_files = FileList["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"

  extra_deps << ["hoe", ">= 2.2.0"]
end

CLEAN.include %w(**/*~ **/*.orig)

task :ci => 'hg:checkin'

ENV['VERSION'] ||= hoespec.spec.version.to_s

