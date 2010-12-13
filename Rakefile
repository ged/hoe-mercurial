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

include Hoe::MercurialHelpers

Hoe.plugin :doofus, :hg
Hoe.plugins.delete :rubyforge


hoespec = Hoe.spec "hoe-hg" do
  developer "McClain Looney", "m@loonsoft.com"
  developer "Michael Granger", "ged@FaerieMUD.org"

  self.extra_rdoc_files = FileList["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"

  self.hg_sign_tags     = false

  extra_deps << ["hoe", "~> 2.8.0"]
end


CLEAN.include %w(**/*~ **/*.orig)


ENV['VERSION'] ||= hoespec.spec.version.to_s


### Task: prerelease
desc "Append the package build number to package versions"
task :pre do
  rev = get_numeric_rev()
  trace "Current rev is: %p" % [ rev ]
  hoespec.spec.version.version << "pre#{rev}"
  Rake::Task[:gem].clear

  Gem::PackageTask.new( hoespec.spec ) do |pkg|
    pkg.need_zip = true
    pkg.need_tar = true
  end
end

