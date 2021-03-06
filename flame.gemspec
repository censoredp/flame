# frozen_string_literal: true

require 'date'

require_relative 'lib/flame/version'

Gem::Specification.new do |s|
	s.name        = 'flame'
	s.version     = Flame::VERSION
	s.date        = Date.today.to_s

	s.summary     = 'Web-framework, based on MVC-pattern'
	s.description = 'Use controller\'s classes with instance methods' \
	                ' as routing actions, mounting its in application class.'

	s.authors     = ['Alexander Popov']
	s.email       = ['alex.wayfer@gmail.com']
	s.homepage    = 'https://github.com/AlexWayfer/flame'
	s.license     = 'MIT'

	s.add_runtime_dependency 'rack', '~> 2'
	s.add_runtime_dependency 'tilt', '>= 2.0', '< 3'
	s.add_runtime_dependency 'gorilla-patch', '~> 2', '>= 2.0.0'
	s.add_runtime_dependency 'thor', '~> 0'

	s.add_development_dependency 'rubocop', '~> 0.48'
	s.add_development_dependency 'rake', '~> 12'
	s.add_development_dependency 'bacon', '~> 1'
	s.add_development_dependency 'bacon-colored_output', '~> 1.1'
	s.add_development_dependency 'rack-test', '~> 0'
	s.add_development_dependency 'simplecov', '~> 0'
	s.add_development_dependency 'codecov', '~> 0'
	s.add_development_dependency 'pry', '~> 0'
	s.add_development_dependency 'pry-byebug', '~> 3'

	s.files = Dir[File.join('{lib,public,template}', '**', '{*,.*}')]
	s.executables = ['flame']
end
