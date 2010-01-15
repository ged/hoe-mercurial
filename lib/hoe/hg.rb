class Hoe #:nodoc:

  # This module is a Hoe plugin. You can set its attributes in your
  # Rakefile Hoe spec, like this:
  #
  #    Hoe.plugin :hg
  #
  #    Hoe.spec "myproj" do
  #      self.hg_release_tag_prefix  = "REL_"
  #      self.hg_repo           = "ssh://hg@bigbucket.org/me/myrepo"
  #      self.hg_release_branch  = "default"
  #    end
  #
  #
  # === Tasks
  #
  # hg:manifest::  Update the manifest with Hg's file list.
  # hg:tag::       Create and push a tag.

  module Hg

    VERSION = "1.0.4"

    attr_accessor :hg_release_tag_prefix
    attr_accessor :hg_repo, :hg_release_branch

    def initialize_hg #:nodoc:
      self.hg_release_tag_prefix = "r"
      self.hg_release_branch = "default"
      self.hg_repo = ""#use whatever is configured in hgrc
    end

    def define_hg_tasks #:nodoc:
      return unless File.exist? ".hg"

      desc "Update the manifest with Hg's file list."
      task "hg:manifest" do
        with_config do |config, _|
          files = `hg manifest`.split "\n"
          File.open "Manifest.txt", "w" do |f|
            f.puts files.sort.join("\n")
          end
        end
      end

      desc "Create and push a TAG (default #{hg_release_tag_prefix}#{version})."

      task "hg:tag" do
        puts "tagging and pushing #{hg_release_branch} to '#{hg_repo}' or whatever you have configured in .hg/hgrc."
        tag ||= "#{hg_release_tag_prefix}#{ENV["VERSION"] || version}"

        hg_tag_and_push tag
      end

      task :release_sanity do
        puts 'doing sanity checks'
        unless `hg status`.strip.length==0
          abort "Won't release: Dirty index or untracked files present!"
        end
      end

      task :release => "hg:tag"
    end

    def hg_tag_and_push tag
      sh "hg tag -m 'tagging #{tag} for release' #{tag}"
      sh "hg push #{hg_repo} -r #{hg_release_branch}" 
    end

  end
end
