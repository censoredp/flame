# frozen_string_literal: true

require_relative 'router'
require_relative 'dispatcher'

module Flame
	## Core class, like Framework::Application
	class Application
		class << self
			attr_accessor :config
		end

		## Framework configuration
		def config
			self.class.config
		end

		## Generating application config when inherited
		def self.inherited(app)
			app.config = Config.new(
				app,
				default_config_dirs(
					root_dir: File.dirname(caller[0].split(':')[0])
				).merge(
					environment: ENV['RACK_ENV'] || 'development'
				)
			)
		end

		def initialize(app = nil)
			@app = app
		end

		## Request recieving method
		def call(env)
			@app.call(env) if @app.respond_to? :call
			Flame::Dispatcher.new(self, env).run!
		end

		## Make available `run Application` without `.new` for `rackup`
		def self.call(env)
			@app ||= new
			@app.call env
		end

		## Mount controller in application class
		## @param ctrl [Flame::Controller] the mounted controller class
		## @param path [String, nil] root path for the mounted controller
		## @yield refine defaults pathes for a methods of the mounted controller
		## @example Mount controller with defaults
		##   mount ArticlesController
		## @example Mount controller with specific path
		##   mount HomeController, '/welcome'
		## @example Mount controller with specific path of methods
		##   mount HomeController do
		##     get '/bye', :goodbye
		##     post '/greetings', :new
		##     defaults
		##   end
		def self.mount(ctrl, path = nil, &block)
			router.add_controller(ctrl, path, &block)
		end

		## Router for routing
		def self.router
			@router ||= Flame::Router.new(self)
		end

		def router
			self.class.router
		end

		## Initialize default for config directories
		def self.default_config_dirs(root_dir:)
			result = { root_dir: File.realpath(root_dir) }
			%i[public views config tmp].each do |key|
				result[:"#{key}_dir"] = proc { File.join(config[:root_dir], key.to_s) }
			end
			result
		end

		## Class for Flame::Application.config
		class Config < Hash
			def initialize(app, hash = {})
				@app = app
				replace(hash)
			end

			def [](key)
				result = super(key)
				if result.class <= Proc && result.parameters.empty?
					result = @app.class_exec(&result)
				end
				result
			end

			## Method for loading YAML-files from config directory
			## @param file [String, Symbol] file name (typecast to String with '.yml')
			## @param key [Symbol, String, nil]
			##   key for allocating YAML in config Hash (typecast to Symbol)
			## @param set [Boolean] allocating YAML in Config Hash
			## @example Load SMTP file from `config/smtp.yml' to config[]
			##   config.load_yaml('smtp.yml')
			## @example Load SMTP file without extension, by Symbol
			##   config.load_yaml(:smtp)
			## @example Load SMTP file with other key to config[:mail]
			##   config.load_yaml('smtp.yml', :mail)
			## @example Load SMTP file without allocating in config[]
			##   config.load_yaml('smtp.yml', set: false)
			def load_yaml(file, key: nil, set: true)
				file = "#{file}.yml" if file.is_a? Symbol
				file_path = File.join(self[:config_dir], file)
				yaml = YAML.load_file(file_path)
				key ||= File.basename(file, '.*')
				self[key.to_sym] = yaml if set
				yaml
			end
		end
	end
end
