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
        semver = SemanticVersion.parse(@version.not_nil!)
      rescue ArgumentError
        Log.debug { "#{@version} is not semver, skipping" }
        return
      rescue NilAssertionError
        Log.debug { "No version defined, skipping" }
        return
      end
      self.versions.each do |v|
        Log.debug { "Checking version candidate: #{v}" }
        begin
          semv = SemanticVersion.parse(v)
        rescue ArgumentError
          Log.debug { "#{v} is not semver, skipping" }
          return
        end
        case ver
        when Versions::Latest
          if semv > semver
            @version = semv.to_s
            Log.info { "Updating req to #{@version}" }
          end
        else
          Log.error { "Updating to non-latest version is not implemented" }
          return
        end
      end
    end
  end

  # Requirement implementation for git
  class GitReq < Req
    # fetch git versions
    def versions : Array(String)
      ["1.0.0", "main", "master", "1.1.0", "2.0.1"] # TODO: implement versions fetch
    end
  end
end
