#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "option_parser"
require "./reqs-up"
require "yaml"

dryrun = false
default_source_file = "requirements.yaml"
source_file = File.new(File::NULL)

OptionParser.parse do |parser|
  parser.banner = "Usage: #{PROGRAM_NAME} [arguments]"
  parser.on("-n", "--dry-run", "Output result YAML to stdout") {
    dryrun = true
  }
  parser.on("-f FILE", "--file=FILE", "Specifies the FILE instead of ./#{default_source_file}") { |file| default_source_file = file }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    abort("ERROR: #{flag} is not a valid option.\n#{parser}")
  end
  parser.missing_option do |flag|
    abort("ERROR: #{flag} is missing something.\n#{parser}")
  end
end

if source_file.path == File::NULL
  begin
    source_file = File.new(default_source_file)
  rescue File::NotFoundError
    abort("ERROR: #{default_source_file} not found")
  end
end

reqs = ReqsUp::Requirements.new(source_file)
# reqs.each do |req|
#   req.update
# end

if dryrun
  puts YAML.dump(reqs.yaml)
else
  reqs.save!(source_file)
end
