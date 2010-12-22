#!rake
#encoding: utf-8

require 'hoe'
require 'rake/clean'

# 1.9.2 and later require explicit relative require
if defined?( require_relative )
	$stderr.puts "Requiring relative lib/hoe/mercurial..."
	require_relative "lib/hoe/mercurial"
	$stderr.puts "	require done."
else
	$LOAD_PATH.unshift( 'lib' )
	require 'hoe/mercurial'
end


Hoe.plugin :mercurial
Hoe.plugin :signing

Hoe.plugins.delete :rubyforge

### Main spec
hoespec = Hoe.spec "hoe-mercurial" do
	developer "Michael Granger", "ged@FaerieMUD.org"

	self.extra_rdoc_files = FileList["*.rdoc"]
	self.history_file     = "History.md"
	self.readme_file      = "README.md"

	self.hg_sign_tags     = false

	extra_deps << ["hoe", "~> 2.8.0"]
end


include Hoe::MercurialHelpers

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


### Make the ChangeLog update if the repo has changed since it was last built
file '.hg/branch'
file 'ChangeLog' => '.hg/branch' do |task|
	log "Updating the changelog..."
	content = make_changelog()
	File.open( task.name, 'w', 0644 ) do |fh|
		fh.print( content )
	end
end

# Rebuild the ChangeLog immediately before release
task :prerelease => 'ChangeLog'


