#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "option_parser"
require "./reqs-up"
require "yaml"
require "log"

dryrun = false
default_source_file = "requirements.yaml"
source_file = File.new(File::NULL)

OptionParser.parse do |parser|
  parser.banner = "Usage: #{PROGRAM_NAME} [arguments]"
  parser.on("-n", "--dry-run", "Output result YAML to stdout") { dryrun = true }
  parser.on("-d", "--debug", "Turn on debug logging") do
    Log.setup(:debug)
  end
  parser.on("-t", "--trace", "Turn on trace logging") do
    Log.setup(:trace)
  end
  parser.on("-f FILE", "--file=FILE", "Specifies the FILE instead of ./#{default_source_file}") { |file| default_source_file = file }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    Log.error { "#{flag} is not a valid option.\n#{parser}" }
    exit 1
  end
  parser.missing_option do |flag|
    Log.error { "#{flag} is missing something.\n#{parser}" }
    exit 2
  end
end

if source_file.path == File::NULL
  begin
    source_file = File.new(default_source_file)
  rescue File::NotFoundError
    Log.error { "#{default_source_file} not found" }
    exit 3
  end
end

reqs = ReqsUp::Requirements.new(source_file)
reqs.reqs.each do |req|
  req.update
end

if dryrun
  puts YAML.dump(reqs.reqs)
else
  reqs.save!(source_file)
end
