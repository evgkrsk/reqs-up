#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "option_parser"
require "./reqs-up"
require "yaml"
require "log"

VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
dryrun = false
logbackend = Log::IOBackend.new(STDERR)
default_source_file = "requirements.yaml"
source_file = File.new(File::NULL)

Log.setup_from_env(default_level: :info, backend: logbackend)

OptionParser.parse do |parser|
  parser.banner = "Usage: #{PROGRAM_NAME} [arguments]\n\nUpdates requirements.yaml file in-place\n"
  parser.on("-n", "--dry-run", "Output result YAML to stdout") { dryrun = true }
  parser.on("-f FILE", "--file=FILE", "Specifies the FILE instead of ./#{default_source_file}") { |file| default_source_file = file }
  parser.on("-h", "--help", "Show this help and exit") do
    puts parser
    exit
  end
  parser.on("-v", "--version", "Print version and exit") do
    puts VERSION
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

requirements = ReqsUp::Requirements.new(source_file)
requirements.reqs.each do |req|
  req.update
end

if dryrun
  puts requirements.dump
else
  requirements.save!
end
