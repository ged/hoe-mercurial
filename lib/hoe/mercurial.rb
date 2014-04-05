#!/usr/bin/env ruby
#coding: utf-8

require 'pathname'
require 'shellwords'
require 'fileutils'
require 'rake/clean'

begin
	require 'readline'
	include Readline
rescue LoadError
	# Fall back to a plain prompt
	def readline( text )
		$stderr.print( text.chomp )
		return $stdin.gets
	end
end

class Hoe

	### Prompting, command-execution, and other utility functions
	module RakeHelpers

		# The editor to invoke if ENV['EDITOR'] and ENV['VISUAL'] aren't set.
		DEFAULT_EDITOR = 'vi'

		# Set some ANSI escape code constants (Shamelessly stolen from Perl's
		# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
		ANSI_ATTRIBUTES = {
			'clear'      => 0,
			'reset'      => 0,
			'bold'       => 1,
			'dark'       => 2,
			'underline'  => 4,
			'underscore' => 4,
			'blink'      => 5,
			'reverse'    => 7,
			'concealed'  => 8,

			'black'      => 30,  'on_black'   => 40,
			'red'        => 31,  'on_red'     => 41,
			'green'      => 32,  'on_green'   => 42,
			'yellow'     => 33,  'on_yellow'  => 43,
			'blue'       => 34,  'on_blue'    => 44,
			'magenta'    => 35,  'on_magenta' => 45,
			'cyan'       => 36,  'on_cyan'    => 46,
			'white'      => 37,  'on_white'   => 47
		}

		# Prompt for multiline input
		MULTILINE_PROMPT = <<-'EOF'
		Enter one or more values for '%s'.
		A blank line finishes input.
		EOF

		# ANSI escapes for clearing to the end of the line and the entire line
		CLEAR_TO_EOL       = "\e[K"
		CLEAR_CURRENT_LINE = "\e[2K"


		###############
		module_function
		###############

		### Create a string that contains the ANSI codes specified and return it
		def ansi_code( *attributes )
			attributes.flatten!
			attributes.collect! {|at| at.to_s }
			# $stderr.puts "Returning ansicode for TERM = %p: %p" %
			#		[ ENV['TERM'], attributes ]
			return '' unless /(?:vt10[03]|xterm(?:-color)?|linux|screen)/i =~ ENV['TERM']
			attributes = ANSI_ATTRIBUTES.values_at( *attributes ).compact.join(';')

			# $stderr.puts "	attr is: %p" % [attributes]
			if attributes.empty?
				return ''
			else
				return "\e[%sm" % attributes
			end
		end


		### Colorize the given +string+ with the specified +attributes+ and return it, handling
		### line-endings, color reset, etc.
		def colorize( *args )
			string = ''

			if block_given?
				string = yield
			else
				string = args.shift
			end

			ending = string[/(\s)$/] || ''
			string = string.rstrip

			return ansi_code( args.flatten ) + string + ansi_code( 'reset' ) + ending
		end


		### Output the specified <tt>msg</tt> as an ANSI-colored error message
		### (white on red).
		def error_message( msg, details='' )
			$stderr.puts colorize( 'bold', 'white', 'on_red' ) { msg } + details
		end
		alias :error :error_message


		### Make a prompt string that will always appear flush left.
		def make_prompt_string( string )
			return CLEAR_CURRENT_LINE + colorize( 'bold', 'green' ) { string + ' ' }
		end


		### Output the specified <tt>prompt_string</tt> as a prompt (in green) and
		### return the user's input with leading and trailing spaces removed.	 If a
		### test is provided, the prompt will repeat until the test returns true.
		### An optional failure message can also be passed in.
		def prompt( prompt_string, failure_msg="Try again." ) # :yields: response
			prompt_string.chomp!
			prompt_string << ":" unless /\W$/.match( prompt_string )
			response = nil

			begin
				prompt = make_prompt_string( prompt_string )
				response = readline( prompt ) || ''
				response.strip!
				if block_given? && ! yield( response )
					error_message( failure_msg + "\n\n" )
					response = nil
				end
			end while response.nil?

			return response
		end


		### Prompt the user with the given <tt>prompt_string</tt> via #prompt,
		### substituting the given <tt>default</tt> if the user doesn't input
		### anything.	 If a test is provided, the prompt will repeat until the test
		### returns true.	 An optional failure message can also be passed in.
		def prompt_with_default( prompt_string, default, failure_msg="Try again." )
			response = nil

			begin
				default ||= '~'
				response = prompt( "%s [%s]" % [ prompt_string, default ] )
				response = default.to_s if !response.nil? && response.empty?

				trace "Validating response %p" % [ response ]

				# the block is a validator.	 We need to make sure that the user didn't
				# enter '~', because if they did, it's nil and we should move on.	 If
				# they didn't, then call the block.
				if block_given? && response != '~' && ! yield( response )
					error_message( failure_msg + "\n\n" )
					response = nil
				end
			end while response.nil?

			return nil if response == '~'
			return response
		end


		### Prompt for an array of values
		def prompt_for_multiple_values( label, default=nil )
			$stderr.puts( MULTILINE_PROMPT % [label] )
			if default
				$stderr.puts "Enter a single blank line to keep the default:\n	%p" % [ default ]
			end

			results = []
			result = nil

			begin
				result = readline( make_prompt_string("> ") )
				if result.nil? || result.empty?
					results << default if default && results.empty?
				else
					results << result
				end
			end until result.nil? || result.empty?

			return results.flatten
		end


		### Display a description of a potentially-dangerous task, and prompt
		### for confirmation. If the user answers with anything that begins
		### with 'y', yield to the block. If +abort_on_decline+ is +true+,
		### any non-'y' answer will fail with an error message.
		def ask_for_confirmation( description, abort_on_decline=true )
			prompt = 'Continue?'

			# If the description looks like a question, use it for the prompt. Otherwise,
			# print it out and
			if description.strip.rindex( '?' )
				prompt = description
			else
				log description
			end

			answer = prompt_with_default( prompt, 'n' ) do |input|
				input =~ /^[yn]/i
			end

			if answer =~ /^y/i
				return yield
			elsif abort_on_decline
				error "Aborted."
				fail
			end

			return false
		end
		alias :prompt_for_confirmation :ask_for_confirmation


		### Output a logging message
		def log( *msg )
			output = colorize( msg.flatten.join(' '), 'cyan' )
			$stderr.puts( output )
		end


		### Output a logging message if tracing is on
		def trace( *msg )
			return unless Rake.application.options.trace
			output = colorize( msg.flatten.join(' '), 'yellow' )
			$stderr.puts( output )
		end


		### Return the specified args as a string, quoting any that have a space.
		def quotelist( *args )
			return args.flatten.collect {|part| part =~ /\s/ ? part.inspect : part}
		end


		### Run the specified command +cmd+ with system(), failing if the execution
		### fails. Doesn't invoke a subshell (unlike 'sh').
		def run( *cmd )
			cmd.flatten!

			if cmd.length > 1
				trace( "Running:", quotelist(*cmd) )
			else
				trace( "Running:", cmd )
			end

			if Rake.application.options.dryrun
				log "(dry run mode)"
			else
				system( *cmd )
				unless $?.success?
					fail "Command failed: [%s]" % [cmd.join(' ')]
				end
			end
		end


		### Invoke the user's editor on the given +filename+ and return the exit code
		### from doing so.
		def edit( filename )
			editor = ENV['EDITOR'] || ENV['VISUAL'] || DEFAULT_EDITOR
			system editor, filename
			unless $?.success? || editor =~ /vim/i
				fail "Editor exited uncleanly."
			end
		end


		### Run the given +cmd+ with the specified +args+ without interpolation by the shell and
		### return anything written to its STDOUT.
		def read_command_output( cmd, *args )
			# output = IO.read( '|-' ) or exec cmd, *args # No popen on some platforms. :(
			argstr = Shellwords.join( args )
			output = `#{cmd} #{argstr}`.chomp
			return output
		end


		### Extract all the non Rake-target arguments from ARGV and return them.
		def get_target_args
			args = ARGV.reject {|arg| arg =~ /^-/ || Rake::Task.task_defined?(arg) }
			return args
		end


		### Returns a human-scannable file list by joining and truncating the list if it's too long.
		def humanize_file_list( list, indent=FILE_INDENT )
			listtext = list[0..5].join( "\n#{indent}" )
			if list.length > 5
				listtext << " (and %d other/s)" % [ list.length - 5 ]
			end

			return listtext
		end

	end # module RakeHelpers


	### Mercurial command wrapper functions.
	module MercurialHelpers
		include FileUtils,
		        Hoe::RakeHelpers
		include FileUtils::DryRun if Rake.application.options.dryrun

		# The name of the ignore file
		IGNORE_FILE = Pathname( '.hgignore' )


		### Generate a commit log from a diff and return it as a String. At the moment it just
		### returns the diff as-is, but will (someday) do something better.
		def make_commit_log
			diff = read_command_output( 'hg', 'diff' )
			fail "No differences." if diff.empty?

			return diff
		end


		### Generate a commit log and invoke the user's editor on it.
		def edit_commit_log( logfile )
			diff = make_commit_log()

			File.open( logfile, 'w' ) do |fh|
				fh.print( diff )
			end

			edit( logfile )
		end


		### Generate a changelog.
		def make_changelog
			log = read_command_output( 'hg', 'log', '--style', 'changelog' )
			return log
		end


		def get_manifest
			raw = read_command_output( 'hg', 'manifest' )
			return raw.split( $/ )
		end


		### Get the 'tip' info and return it as a Hash
		def get_tip_info
			data = read_command_output( 'hg', 'tip' )
			return YAML.load( data )
		end


		### Return the ID for the current rev
		def get_current_rev
			id = read_command_output( 'hg', '-q', 'identify' )
			return id.chomp
		end


		### Return the current numeric (local) rev number
		def get_numeric_rev
			id = read_command_output( 'hg', '-q', 'identify', '-n' )
			return id.chomp[ /^(\d+)/, 1 ] || '0'
		end


		### Read the list of existing tags and return them as an Array
		def get_tags
			taglist = read_command_output( 'hg', 'tags' )
			return taglist.split( /\n/ ).collect {|tag| tag[/^\S+/] }
		end


		### Read any remote repo paths known by the current repo and return them as a hash.
		def get_repo_paths
			paths = {}
			pathspec = read_command_output( 'hg', 'paths' )
			pathspec.split.each_slice( 3 ) do |name, _, url|
				paths[ name ] = url
			end
			return paths
		end


		### Return the list of files which are not of status 'clean'
		def get_uncommitted_files
			list = read_command_output( 'hg', 'status', '-n', '--color', 'never' )
			list = list.split( /\n/ )

			trace "Changed files: %p" % [ list ]
			return list
		end


		### Return the list of files which are of status 'unknown'
		def get_unknown_files
			list = read_command_output( 'hg', 'status', '-un', '--color', 'never' )
			list = list.split( /\n/ )

			trace "New files: %p" % [ list ]
			return list
		end


		### Add the list of +pathnames+ to the .hgignore list.
		def hg_ignore_files( *pathnames )
			patterns = pathnames.flatten.collect do |path|
				'^' + Regexp.escape(path) + '$'
			end
			trace "Ignoring %d files." % [ pathnames.length ]

			IGNORE_FILE.open( File::CREAT|File::WRONLY|File::APPEND, 0644 ) do |fh|
				fh.puts( patterns )
			end
		end


		### Delete the files in the given +filelist+ after confirming with the user.
		def delete_extra_files( filelist )
			description = humanize_file_list( filelist, '	 ' )
			log "Files to delete:\n ", description
			ask_for_confirmation( "Really delete them?", false ) do
				filelist.each do |f|
					rm_rf( f, :verbose => true )
				end
			end
		end

	end # module MercurialHelpers


	### Hoe plugin module
	module Mercurial
		include Hoe::RakeHelpers,
		        Hoe::MercurialHelpers

		VERSION = '1.4.1'

		# The name of the file to edit for the commit message
		COMMIT_MSG_FILE = 'commit-msg.txt'

		attr_accessor :hg_release_tag_prefix
		attr_accessor :hg_sign_tags
		attr_accessor :check_history_on_release


		### Set up defaults
		def initialize_mercurial
			# Follow semantic versioning tagging specification (http://semver.org/)
			self.hg_release_tag_prefix    = "v"
			self.hg_sign_tags             = false
			self.check_history_on_release = false

			minor_version = VERSION[ /^\d+\.\d+/ ]
			self.extra_dev_deps << ['hoe-mercurial', "~> #{minor_version}"] unless
				self.name == 'hoe-mercurial'
		end


		### Read the list of tags and return any that don't have a corresponding section
		### in the history file.
		def get_unhistoried_version_tags( include_pkg_version=true )
			prefix = self.hg_release_tag_prefix
			tag_pattern = /#{prefix}\d+(\.\d+)+/
			release_tags = get_tags().grep( /^#{tag_pattern}$/ )

			release_tags.unshift( "#{prefix}#{version}" ) if include_pkg_version

			IO.readlines( self.history_file ).each do |line|
				if line =~ /^(?:h\d\.|#+|=+)\s+(#{tag_pattern})\s+/
					trace "  found an entry for tag %p: %p" % [ $1, line ]
					release_tags.delete( $1 )
				else
					trace "  no tag on line %p" % [ line ]
				end
			end

			return release_tags
		end


		### Hoe hook -- Define Rake tasks when the plugin is loaded.
		def define_mercurial_tasks
			return unless File.exist?( ".hg" ) &&
				!Rake::Task.task_defined?( 'hg:checkin' )

			file COMMIT_MSG_FILE do |task|
				edit_commit_log( task.name )
			end

			namespace :hg do

				desc "Prepare for a new release"
				task :prep_release do
					uncommitted_files = get_uncommitted_files()
					unless uncommitted_files.empty?
						log "Uncommitted files:\n",
							*uncommitted_files.map {|fn| "	#{fn}\n" }
						ask_for_confirmation( "\nRelease anyway?", true ) do
							log "Okay, releasing with uncommitted versions."
						end
					end

					tags = get_tags()
					rev = get_current_rev()
					pkg_version_tag = "#{hg_release_tag_prefix}#{version}"

					# Look for a tag for the current release version, and if it exists abort
					if tags.include?( pkg_version_tag )
						error "Version #{version} already has a tag."
						fail
					end

					# Ensure that the History file contains an entry for every release
					Rake::Task[ 'check_history' ].invoke if self.check_history_on_release

					# Sign the current rev
					if self.hg_sign_tags
						log "Signing rev #{rev}"
						run 'hg', 'sign'
					end

					# Tag the current rev
					log "Tagging rev #{rev} as #{pkg_version_tag}"
					run 'hg', 'tag', pkg_version_tag

					# Offer to push
					Rake::Task['hg:push'].invoke
				end


				desc "Check for new files and offer to add/ignore/delete them."
				task :newfiles do
					log "Checking for new files..."

					entries = get_unknown_files()

					unless entries.empty?
						files_to_add = []
						files_to_ignore = []
						files_to_delete = []

						entries.each do |entry|
							action = prompt_with_default( "	 #{entry}: (a)dd, (i)gnore, (s)kip (d)elete", 's' )
							case action
							when 'a'
								files_to_add << entry
							when 'i'
								files_to_ignore << entry
							when 'd'
								files_to_delete << entry
							end
						end

						unless files_to_add.empty?
							run 'hg', 'add', *files_to_add
						end

						unless files_to_ignore.empty?
							hg_ignore_files( *files_to_ignore )
						end

						unless files_to_delete.empty?
							delete_extra_files( files_to_delete )
						end
					end
				end
				task :add => :newfiles


				desc "Pull and update from the default repo"
				task :pull do
					paths = get_repo_paths()
					if origin_url = paths['default']
						ask_for_confirmation( "Pull and update from '#{origin_url}'?", false ) do
							Rake::Task['hg:pull_without_confirmation'].invoke
						end
					else
						trace "Skipping pull: No 'default' path."
					end
				end


				desc "Pull and update without confirmation"
				task :pull_without_confirmation do
					run 'hg', 'pull', '-u'
				end


				desc "Update to tip"
				task :update do
					run 'hg', 'update'
				end


				desc "Clobber all changes (hg up -C)"
				task :update_and_clobber do
					run 'hg', 'update', '-C'
				end


				task :precheckin do
					trace "Pre-checkin hooks"
				end


				desc "Check the current code in if tests pass"
				task :checkin => [:pull, :newfiles, :precheckin, COMMIT_MSG_FILE] do
					targets = get_target_args()
					$stderr.puts '---', File.read( COMMIT_MSG_FILE ), '---'
					ask_for_confirmation( "Continue with checkin?" ) do
						run 'hg', 'ci', '-l', COMMIT_MSG_FILE, targets
						rm_f COMMIT_MSG_FILE
					end
					Rake::Task['hg:push'].invoke
				end
				task :commit => :checkin
				task :ci => :checkin

				CLEAN.include( COMMIT_MSG_FILE )

				desc "Push to the default origin repo (if there is one)"
				task :push do
					paths = get_repo_paths()
					if origin_url = paths['default']
						ask_for_confirmation( "Push to '#{origin_url}'?", false ) do
							Rake::Task['hg:push_without_confirmation'].invoke
						end
					else
						trace "Skipping push: No 'default' path."
					end
				end

				desc "Push to the default repo without confirmation"
				task :push_without_confirmation do
					run 'hg', 'push'
				end
			end

			# Add a top-level 'ci' task for checkin
			desc "Check in your changes"
			task :ci => 'hg:checkin'

			# Hook the release task and prep the repo first
			task :prerelease => 'hg:prep_release'

			desc "Check the history file to ensure it contains an entry for each release tag"
			task :check_history do
				log "Checking history..."
				missing_tags = get_unhistoried_version_tags()

				unless missing_tags.empty?
					abort "%s needs updating; missing entries for tags: %p" %
						[ self.history_file, missing_tags ]
				end
			end

		rescue ::Exception => err
			$stderr.puts "%s while defining Mercurial tasks: %s" % [ err.class.name, err.message ]
			raise
		end

	end
end
