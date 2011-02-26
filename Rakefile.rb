require 'rubygems'    

require 'albacore'
require 'rake/clean'
require 'noodle'

include FileUtils

solution_file = FileList["*.sln"].first
build_file = FileList["*.msbuild"].first
project_name = "MavenThought.MovieLibrary"

CLEAN.include("main/**/bin", "main/**/obj", "test/**/obj", "test/**/bin")

CLOBBER.include("**/_*", "lib/*", "**/*.user", "**/*.cache", "**/*.suo")

desc 'Default build'
task :default => ["build:all"]

desc 'Setup requirements to build and deploy'
task :setup => ["setup:dep:local"]

namespace :setup do
	namespace :dep do
		Noodle::Rake::NoodleTask.new :local do |n|
			n.groups << :runtime
			n.groups << :dev
		end
	end
end

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

desc "Run all tests"
task :test => ["test:all"]

namespace :test do
	
	desc 'Run all tests'
	task :all => [:default] do 
		tests = FileList["test/**/bin/debug/**/*.Tests.dll"].join " "
		system "./tools/gallio/bin/gallio.echo.exe #{tests}"
	end

end

desc "Commit"
task :commit => [:test] do
	sh '"C:\Program Files\TortoiseSVN\bin\TortoiseProc.exe" /command:commit /path:"." /notempfile'
end

