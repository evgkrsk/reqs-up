#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "semantic_version"
require "yaml"

module ReqsUp
  Log = ::Log.for(self)

  enum Versions
    Latest
    Minor
    Major
    Patch
  end

  # Describes requirements.yml object
  class Requirements
    Log = ::Log.for(self)
    include YAML::Serializable
    # All requirements
    getter reqs : Array(Req) = [] of Req
    # raw yaml content
    getter yaml : YAML::Any

    # Initialize requirements object from *file* object
    def initialize(@file : File)
      @yaml = YAML.parse(@file.gets_to_end)
      @yaml.as_a.each do |y|
        Log.debug { "#{y}" }
        case y["scm"]?
        when Nil, "git"
          @reqs << GitReq.new(y)
        else
          Log.error { "Unsupported SCM: #{y["scm"]}, skipping" }
        end
      end
      Log.trace { "Reqs: #{@reqs}" }
    end

    # Return YAML dump of internal state
    def dump
      YAML.dump(@reqs) + "...\n"
    end

    # Save object to *dest* File
    def save!(dest = @file)
      Log.debug { "Writing requirements to #{@file.path}" }
      File.write(@file.path, dump)
    end
  end

  # Requirement skeleton
  abstract class Req
    include YAML::Serializable
    property src : String
    property name : String | Nil
    property version : String | Nil
    getter scm : String | Nil
    Log = ::Log.for(self)

    # Initialize one requirements from YAML element
    def initialize(req : YAML::Any)
      @src = req["src"].as_s
      if req["name"]?
        @name = req["name"].as_s
      end
      if req["version"]?
        @version = req["version"].as_s
      end
      if req["scm"]?
        @scm = req["scm"].as_s
      end
    end

    # Return all available req versions
    abstract def versions : Array(String)

    # Print object
    def to_s(io : IO) : Nil
      io << "#<" << self.class.name
      io << ":#{@src}"
      io << " #{@scm}"
      io << " #{@name}"
      io << " #{@version}"
      io << '>'
    end

    # Update requirement version, returns final version
    def update(ver : Versions = Versions::Latest) : String | Nil
      Log.debug { "Updating req #{self}" }
      begin
        watermark = SemanticVersion.parse(@version.not_nil!)
        current = watermark
      rescue ArgumentError
        Log.debug { "#{@version} is not semver, skipping" }
        return
      rescue NilAssertionError
        Log.debug { "No version defined, skipping" }
        return
      end
      Log.debug { "Current version: #{@version}" }
      versions.each do |v|
        Log.trace { "Checking version candidate: #{v}" }
        begin
          candidate = SemanticVersion.parse(v)
        rescue ArgumentError
          Log.trace { "#{v} is not semver, skipping" }
          next
        end
        case ver
        when Versions::Latest
          if candidate > watermark
            watermark = candidate
            Log.trace { "Feasible candidate: #{watermark}" }
          end
        else
          Log.error { "Updating to non-latest version is not implemented" }
          return
        end
      end
      if watermark > current
        @version = watermark.to_s
        Log.info { "Updating #{@src} to #{@version}" }
      end
      @version
    end
  end

  # Requirement implementation for git
  class GitReq < Req
    Log = ::Log.for(self)

    # fetch git versions
    def versions : Array(String)
      result : Array(String) = [] of String
      git = Process.find_executable("git")
      if git.nil?
        Log.error { "Cant find git executable" }
        return result
      end
      proccmd = "#{git} ls-remote --tags --refs #{@src}"
      Log.debug { "Running \"#{proccmd}\" to fetch tags" }
      process = Process.new(git, ["ls-remote", "--tags", "--refs", @src], output: Process::Redirect::Pipe)
      process.output.each_line do |line|
        tag = line.split('/')[2]
        Log.trace { "Got tag: #{tag}" }
        result << tag
      end
      status = process.wait
      if !status.success?
        Log.error { "Running \"#{proccmd}\" failed" }
      end
      result
    end
  end
end
