#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "option_parser"

dryrun = false
destination = "requirements.yaml"

OptionParser.parse do |parser|
  parser.banner = "Usage: #{PROGRAM_NAME} [arguments]"
  parser.on("-n", "--dry-run", "Output result YAML to stdout") { dryrun = true }
  parser.on("-f FILE", "--file=FILE", "Specifies the FILE instead of ./#{destination}") { |file| destination = file }
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
