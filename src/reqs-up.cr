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
    abstract def versions : Tuple(String)

    # Update requirement version
    def update(ver : Versions = Versions::Latest) : Nil
      # TODO: implement version update
    end
  end

  # Requirement implementation for git
  class GitReq < Req
    # @versions : Tuple(String)

    # fetch git versions
    def versions : Tuple(String)
      {"1.0.0", "main", "master", "1.1.0", "2.0.1"} # TODO: implement versions fetch
    end
  end
end
