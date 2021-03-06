# frozen_string_literal: true

require 'forwardable'
require_relative 'render'

module Flame
	## Class initialize when Dispatcher found route with it
	## For new request and response
	class Controller
		extend Forwardable

		## Shortcut for not-inherited public methods: actions
		def self.actions
			public_instance_methods(false)
		end

		def_delegators(
			:@dispatcher,
			:config, :request, :params, :halt, :session, :response, :status, :body,
			:default_body
		)

		## Initialize the controller for request execution
		## @param dispatcher [Flame::Dispatcher] dispatcher object
		def initialize(dispatcher)
			@dispatcher = dispatcher
		end

		## Helpers
		def path_to(*args)
			add_controller_class(args)
			@dispatcher.path_to(*args)
		end

		## Build a URI to the given controller and action, or path
		def url_to(*args)
			path = args.first.is_a?(String) ? args.first : path_to(*args)
			"#{request.scheme}://#{request.host_with_port}#{path}"
		end

		## Redirect for response
		## @overload redirect(path)
		##   Redirect to the string path
		##   @param path [String] path
		##   @example Redirect to '/hello'
		##     redirect '/hello'
		## @overload redirect(*args)
		##   Redirect to the path of `path_to` method
		##   @param args arguments for `path_to` method
		##   @example Redirect to `show` method of `ArticlesController` with id = 2
		##     redirect ArticlesController, :show, id: 2
		def redirect(*params)
			response.redirect(
				params[0].is_a?(String) ? params[0] : path_to(*params)
			)
		end

		# Set the Content-Disposition to "attachment" with the specified filename,
		# instructing the user agents to prompt to save.
		def attachment(filename = nil, disposition = :attachment)
			content_dis = 'Content-Disposition'
			response[content_dis] = disposition.to_s
			return unless filename
			response[content_dis] << "; filename=\"#{File.basename(filename)}\""
			ext = File.extname(filename)
			response.content_type = ext unless ext.empty?
		end

		## Render a template with `Flame::Render` (based on Tilt-engine)
		## @param path [Symbol, nil] path to the template file
		## @param options [Hash] options for the `Flame::Render` rendering
		## @return [String] rendered template
		def view(path = nil, options = {})
			cache = options.delete(:cache)
			cache = config[:environment] == 'production' if cache.nil?
			template = Flame::Render.new(
				self,
				(path || caller_locations(1, 1)[0].label.to_sym),
				options
			)
			template.render(cache: cache)
		end
		alias render view

		protected

		## Execute the method of the controller with hooks (may be overloaded)
		## @param method [Symbol] name of the controller method
		def execute(method)
			# send method
			body send(method, *select_args(method))
		end

		## Default method for Internal Server Error, can be inherited
		def server_error(_exception)
			body default_body
		end

		private

		def select_args(method)
			parameters = self.class.instance_method(method).parameters
			params_select = proc do |type|
				params.values_at(
					*parameters.select { |par| par.first == type }.map(&:last)
				)
			end
			params_select.call(:req) + params_select.call(:opt).compact
		end

		def add_controller_class(args)
			args.unshift(self.class) if args[0].is_a?(Symbol)
			args.insert(1, :index) if args[0].is_a?(Class) && !args[1].is_a?(Symbol)
		end

		class << self
			using GorillaPatch::Inflections

			## Default root path of the controller for requests
			def default_path
				modules = name.underscore.split('/')
				parts = modules[-1].split('_') - %w[index controller ctrl]
				return modules[-2] if parts.empty?
				parts.join('_')
			end

			## Re-define public instance method from parent
			## @example Inherit controller with parent actions by method
			##   class MyController < BaseController.with_actions
			##   end
			def with_actions
				@with_actions ||= Class.new(self) { extend ParentActions }
			end
		end

		## Module for public instance methods re-defining from superclass
		## @example Inherit controller with parent actions by `extend`
		##   class MyController < BaseController
		##     extend Flame::Controller::ParentActions
		##   end
		module ParentActions
			def inherited(ctrl)
				ctrl.define_parent_actions
			end

			def self.extended(ctrl)
				ctrl.define_parent_actions
			end

			def define_parent_actions
				superclass.actions.each do |public_method|
					um = superclass.public_instance_method(public_method)
					define_method public_method, um
				end
			end
		end
	end
end
