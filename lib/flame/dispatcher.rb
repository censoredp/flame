# frozen_string_literal: true

require 'gorilla-patch/symbolize'

require_relative 'cookies'
require_relative 'request'
require_relative 'response'
require_relative 'static'

module Flame
	## Helpers for dispatch Flame::Application#call
	class Dispatcher
		attr_reader :request, :response

		include Flame::Dispatcher::Static

		## Initialize Dispatcher from Application#call
		## @param app [Flame::Application] application object
		## @param env Rack-environment object
		def initialize(app, env)
			@app = app
			@env = env
			@request = Flame::Request.new(env)
			@response = Flame::Response.new
		end

		## Start of execution the request
		def run!
			catch :halt do
				try_static ||
					try_static(File.join(__dir__, '..', '..', 'public')) ||
					try_route ||
					halt(404)
			end
			response.write body
			response.finish
		end

		## Acccess to the status of response
		## @param value [Ineger, nil] integer value for new status
		## @return [Integer] current status
		## @example Set status value
		##   status 200
		def status(value = nil)
			response.status ||= 200
			response.headers['X-Cascade'] = 'pass' if value == 404
			value ? response.status = value : response.status
		end

		## Acccess to the body of response
		## @param value [String, nil] string value for new body
		## @return [String] current body
		## @example Set body value
		##   body 'Hello World!'
		def body(value = nil)
			value ? @body = value : @body ||= ''
		end

		using GorillaPatch::Symbolize

		## Parameters of the request
		def params
			@params ||= request.params.symbolize_keys(deep: true)
		end

		## Session object as Hash
		def session
			request.session
		end

		## Cookies object as Hash
		def cookies
			@cookies ||= Cookies.new(request.cookies, response)
		end

		## Application-config object as Hash
		def config
			@app.config
		end

		## Build a path to the given controller and action, with any expected params
		##
		## @param ctrl [Flame::Controller] class of controller
		## @param action [Symbol] method of controller
		## @param args [Hash] parameters for method of controller
		## @return [String] path for requested method, controller and parameters
		## @example Path for `show(id)` method of `ArticlesController` with `id: 2`
		##   path_to ArticlesController, :show, id: 2 # => "/articles/show/2"
		## @example Path for `new` method of `ArticlesController` with params
		##   path_to ArticlesController, :new, params: { author_id: 1 }
		##   # => "/articles/new?author_id=1"
		def path_to(ctrl, action = :index, args = {})
			route = @app.class.router.find_route(controller: ctrl, action: action)
			raise Errors::RouteNotFoundError.new(ctrl, action) unless route
			params = Rack::Utils.build_nested_query args.delete(:params)
			path = route.assign_arguments(args)
			path = '/' if path.empty?
			URI::Generic.build(path: path, query: params).to_s
		end

		## Interrupt the execution of route, and set new optional data
		##   (otherwise using existing)
		## @param new_status [Integer, nil]
		##   set new HTTP status code
		## @param new_body [String, nil] set new body
		## @param new_headers [Hash, nil] merge new headers
		## @example Halt, no change status or body
		##   halt
		## @example Halt with 500, no change body
		##   halt 500
		## @example Halt with 404, render template
		##   halt 404, render('errors/404')
		## @example Halt with 200, set new headers
		##   halt 200, 'Cats!', 'Content-Type' => 'animal/cat'
		def halt(new_status = nil, new_body = nil, new_headers = {})
			status new_status if new_status
			body new_body || (default_body_of_nearest_route if body.empty?)
			response.headers.merge!(new_headers)
			throw :halt
		end

		## Add error's backtrace to @env['rack.errors'] (terminal or file)
		## @param error [Exception] exception for class, message and backtrace
		def dump_error(error)
			error_message = [
				"#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - " \
				"#{error.class} - #{error.message}:",
				*error.backtrace
			].join("\n\t")
			@env[Rack::RACK_ERRORS].puts(error_message)
		end

		## Generate default body of error page
		def default_body
			# response.headers[Rack::CONTENT_TYPE] = 'text/html'
			"<h1>#{Rack::Utils::HTTP_STATUS_CODES[status]}</h1>"
		end

		private

		## Find route and try execute it
		def try_route
			route = @app.class.router.find_route(
				method: request.http_method,
				path_parts: request.path_parts
			)
			return nil unless route
			execute_route(route)
		end

		## Execute route
		## @param route [Flame::Route] route that must be executed
		def execute_route(route)
			status 200
			params.merge!(route.arguments(request.path_parts))
			# route.execute(self)
			controller = route.controller.new(self)
			controller.send(:execute, route.action)
		rescue => exception
			# p 'rescue from dispatcher'
			dump_error(exception)
			status 500
			controller.send(:server_error, exception)
			# p 're raise exception from dispatcher'
			# raise exception
		end

		## Generate a default body of nearest route
		def default_body_of_nearest_route
			## Return nil if must be no body for current HTTP status
			return if Rack::Utils::STATUS_WITH_NO_ENTITY_BODY.include?(status)
			## Find the nearest route by the parts of requested path
			route = @app.router.find_nearest_route(request.path_parts)
			## Return nil if the route not found
			##   or it's `default_body` method not defined
			return default_body unless route
			## Execute `default_body` method for the founded route
			route.controller.new(self).send(:execute, :default_body)
			default_body if body.empty?
		end
	end
end
