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
    class_getter number : Int32 = 0 # number of Req-s in Requirements
    getter reqs : Array(Req)
    getter yaml : YAML::Any

    # Initialize requirements object from *file* object

    def initialize(@file : File)
      @@number += 1
      @reqs = [] of Req
      # TODO: implement loading from YAML to reqs
      @yaml = YAML.parse(@file.gets_to_end)
      # p @yaml.as_a
      # @yaml.each do |y|
      #   @reqs << Req.new(y["src"])
      # end
    end

    def save!(dest)
      Nil
    end
  end

  # Requirement skeleton
  abstract class Req
    include YAML::Serializable
    property src : String
    property name : String
    property version : String = "master"
    getter scm : String = "git"

    def initialize(src : String, **attrs)
      @src = src
      if attrs.has_key?(:name)
        @name = attrs[:name]
      else
        @name = self.get_name
      end
      if attrs.has_key?(:version)
        @version = attrs[:version]
      end
      if attrs.has_key?(:scm)
        @scm = attrs[:scm]
      end
    end

    # Determine req name from src
    abstract def get_name : String

    # Return all available req versions
    abstract def versions : Tuple(String)

    # Update requirement version
    def update(ver : Versions = Versions::Latest) : Nil
      # TODO: implement version update
    end
  end

  # Requirement implementation for git
  class GitReq < Req
    @@scm = "git"
    @name : String = "FIXME"

    # @versions : Tuple(String)

    # fetch git versions
    def versions : Tuple(String)
      {"1.0.0", "main", "master", "1.1.0", "2.0.1"} # TODO: implement versions fetch
    end

    def get_name : String
      @name
    end
  end
end
