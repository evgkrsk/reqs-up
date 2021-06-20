#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "option_parser"
require "./reqs-up"

dryrun = false
source_file = File.new("requirements.yaml")
destination_file = source_file

OptionParser.parse do |parser|
  parser.banner = "Usage: #{PROGRAM_NAME} [arguments]"
  parser.on("-n", "--dry-run", "Output result YAML to stdout") {
    dryrun = true
    destination_file = STDOUT
  }
  parser.on("-f FILE", "--file=FILE", "Specifies the FILE instead of ./#{source_file.path}") { |file| source_file = File.new(file) }
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

reqs = ReqsUp::Requirements.new(source_file)
# reqs.each do |req|
#   req.update
# end
reqs.save!(destination_file)
