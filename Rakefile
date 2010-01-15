$: << "lib"
require 'rake/clean'
CLEAN.include %w(**/*~ **/*.orig)
require "rubygems"
require "hoe"
require "hoe/hg"

ENV['VERSION']=Hoe::Hg::VERSION
Hoe.plugin :doofus, :hg


Hoe.spec "hoe-hg" do
  developer "McClain Looney", "m@loonsoft.com"

  self.extra_rdoc_files = FileList["*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"

  extra_deps << ["hoe", ">= 2.2.0"]
end
