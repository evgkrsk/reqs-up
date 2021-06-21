#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "semantic_version"
require "yaml"

module ReqsUp
  enum Versions
    Latest
    Minor
    Major
    Patch
  end

  # Describes requirements.yaml object
  class Requirements
    include YAML::Serializable
    # All requirements
    getter reqs : Array(Req) = [] of Req
    # raw yaml content
    getter yaml : YAML::Any

    # Initialize requirements object from *file* object
    def initialize(@file : File)
      @yaml = YAML.parse(@file.gets_to_end)
      @yaml.as_a.each do |y|
        Log.debug { "Req: #{y}" }
        case y["scm"]?
        when Nil, "git"
          @reqs << GitReq.new(y)
        else
          Log.error { "ERROR: Unsupported SCM: #{y["scm"]}, skipping" }
        end
      end
      Log.debug { "Reqs: #{@reqs}" }
    end

    # Save object to *dest* File
    def save!(dest)
      Nil # TODO
    end
  end

  # Requirement skeleton
  abstract class Req
    include YAML::Serializable
    property src : String
    property name : String | Nil
    property version : String | Nil
    getter scm : String | Nil

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
        Log.debug { "Checking version candidate: #{v}" }
        begin
          candidate = SemanticVersion.parse(v)
        rescue ArgumentError
          Log.debug { "#{v} is not semver, skipping" }
          next
        end
        case ver
        when Versions::Latest
          if candidate > watermark
            watermark = candidate
            Log.debug { "Feasible candidate: #{watermark}" }
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
    # fetch git versions
    def versions : Array(String)
      ["1.6.0", "main", "master", "4.1.0", "2.1.1"] # TODO: implement versions fetch
    end
  end
end
