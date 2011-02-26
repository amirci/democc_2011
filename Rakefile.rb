require 'rubygems'    

require 'albacore'
require 'rake/clean'

include FileUtils

solution_file = FileList["*.sln"].first
build_file = FileList["*.msbuild"].first
project_name = "MavenThought.MovieLibrary"

CLEAN.include("main/**/bin", "main/**/obj", "test/**/obj", "test/**/bin")

CLOBBER.include("**/_*", "lib/*", "**/*.user", "**/*.cache", "**/*.suo")

desc 'Default build'
task :default => ["build:all"]

namespace :build do

	desc "Build the project"
	msbuild :all, :config do |msb, args|
		msb.properties :configuration => args[:config] || :Debug
		msb.targets :Build
		msb.solution = solution_file
	end

	desc "Rebuild the project"
	task :re => ["clean", "build:all"]
end

