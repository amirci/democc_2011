require 'rubygems'    

require 'albacore'
require 'rake/clean'
require 'noodle'
require 'git'


include FileUtils

solution_file = FileList["*.sln"].first
build_file = FileList["*.msbuild"].first
project_name = "MavenThought.MovieLibrary"

CLEAN.include("main/**/bin", "main/**/obj", "test/**/obj", "test/**/bin")

CLOBBER.include("**/_*", "lib/*", "**/*.user", "**/*.cache", "**/*.suo")

desc 'Default build'
task :default => ["setup", "build:all"]

desc 'Setup requirements to build and deploy'
task :setup => ["setup:dep"]

namespace :setup do
	desc "Setup dependencies for nuget packages"
	task :dep do
		FileList["**/packages.config"].each do |file|
			sh "nuget install #{file} /OutputDirectory Packages"
		end
	end
end

namespace :build  do

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

desc "Builds, tests and then commits with SVN dialog"
task :push => ["tools:stylecop", :test] do
	sh "git push origin master"
end

namespace :tools do
	require 'rexml/document'

	desc "Runs stylecop and generates a report on the Output folder"
	task :stylecop do
		mkdir "Output" unless File.directory? "Output"
		stylecop = "tools/stylecopcmd/StyleCopCmd"
		# Run the StyleCopCmd from tools
		sh "#{stylecop} -sf #{solution_file} -ifp AssemblyInfo.cs -of output/stylecop.xml -sc Settings.StyleCop -tf tools/StyleCopCmd/StyleCopReport.xsl"
		sh "tools/Xslt/msxsl.exe Output/stylecop.violations.xml tools/stylecopcmd/ViolationsReport.xsl -o Output/StyleCop.Violations.html"

		xmldoc = REXML::Document.new(File.new("Output/stylecop.violations.xml"))
		violations = REXML::XPath.first(xmldoc, "/StyleCopViolations/Violation")
		abort "Stylecop Failed! Please check output\\stylecop.violations.html!" unless violations.nil?
	end
end

desc "Updates build version and generates zip"
task :deploy => ["deploy:all"]

namespace :deploy do
		
	commit = Git.open(".").log.first.sha[0..10] rescue 'na'
	version = IO.readlines('VERSION')[0] rescue "0.0.0.0"

	deploy_folder = "c:/temp/build/#{project_name}.#{version}"

	task :all  => [:update_version] do
		rm_rf(deploy_folder)
		Dir.mkdir(deploy_folder) unless File.directory? deploy_folder
		Rake::Task["build:all"].invoke(:Release)
		Rake::Task["deploy:package"].invoke
	end 
	
	task :update_version do 
		files = FileList["main/**/Properties/AssemblyInfo.cs"]
		ass = Rake::Task["deploy:assemblyinfo"]
		files.each do |file| 
			ass.invoke(file) 
			ass.reenable
		end
	end
	
	assemblyinfo :assemblyinfo, :file do |asm, args|
		asm.version = version
		asm.company_name = "MavenThought Inc."
		asm.product_name = "MavenThought MovieLibrary"
		asm.title = "MavenThought Library Demo"
		asm.description = "Demo done for Winnipeg CodeCamp 2011"
		asm.copyright = "MavenThought Inc. 2011"
		asm.output_file = args[:file]
	end	
	
	zip :package do |zip|
		Dir.mkdir(deploy_folder) unless File.directory? deploy_folder
		zip_file = "#{project_name}.#{version}.zip"
		puts "Creating zip file #{zip_file} in #{deploy_folder}"
		zip.directories_to_zip "main/MavenThought.MediaLibrary.WebClient/bin"
		zip.output_file = zip_file
		zip.output_path = deploy_folder
	end
end


