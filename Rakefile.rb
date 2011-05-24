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

CLOBBER.include("**/_*", "lib/*", "**/*.user", "**/*.cache", "**/*.suo", "packages")

desc 'Default build'
task :default => ["setup", "build:all"]

desc 'Setup requirements to build and deploy'
task :setup => ["setup:os"]

namespace :setup do
	desc "Setup dependencies for nuget packages"
	task :dep do
		FileList["**/packages.config"].each do |file|
			sh "nuget install #{file} /OutputDirectory Packages"
		end
	end
	
	desc "Setup dependencies for this OS (x86/x64)"
	task :os => ["setup:dep"] do
		setup_os
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

namespace :util do
	task :clean_folder, :folder do |t, args|
		rm_rf(args.folder)
		Dir.mkdir(args.folder) unless File.directory? args.folder
	end
		
	assemblyinfo :update_version do |asm|
		asm.version = version
		asm.file_version = version
		asm.product_name = "MovieLibrary Demo (sha #{commit})"
		asm.output_file = "main/GlobalAssemblyInfo.cs"
		asm.copyright = "MavenThought Inc - 2011"
		asm.trademark = commit
	end	

	task :pre_publish, :config do |t, args|
		Rake::Task["build:all"].invoke(args.config)
		Rake::Task["test"].invoke
	end
end

def setup_os(target = nil)
	target ||= File.exist?('c:\Program Files (x86)') ? 64 : 32
	puts "**** Setting up OS #{target} bits"
	files = FileList["Packages/SQLitex64.1.0.66/lib/#{target}/*.dll"].first
	puts "**** Using #{files}"
	FileUtils.cp(files, "Packages/SQLitex64.1.0.66/lib/")
end