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

desc "Builds, tests and then commits with SVN dialog"
task :commit => ["tools:stylecop", :test] do
	sh '"C:\Program Files\TortoiseSVN\bin\TortoiseProc.exe" /command:commit /path:"." /notempfile'
end

require 'rexml/document'
include REXML

namespace :tools do
	desc "Runs stylecop and generates a report on the Output folder"
	task :stylecop do
		mkdir "Output" unless File.directory? "Output"
		stylecop = "tools/stylecopcmd/StyleCopCmd"
		# Run the StyleCopCmd from tools
		sh "#{stylecop} -sf #{solution_file} -ifp AssemblyInfo.cs -of output/stylecop.xml -sc Settings.StyleCop -tf tools/StyleCopCmd/StyleCopReport.xsl"
		sh "tools/Xslt/msxsl.exe Output/stylecop.violations.xml tools/stylecopcmd/ViolationsReport.xsl -o Output/StyleCop.Violations.html"

		xmldoc = Document.new(File.new("Output/stylecop.violations.xml"))
		violations = XPath.first(xmldoc, "/StyleCopViolations/Violation")
		abort "Stylecop Failed! Please check output\stylecop.violations.html!" unless violations.nil?
	end
end

desc "Updates build version and generates zip"
task :deploy => ["deploy:all"]

namespace :deploy do
		
	svnrevision = `tools/svn/svnversion`.match('\d+:(\d+).*')[1] rescue '0'

	version = "1.1.0.#{svnrevision}"

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


