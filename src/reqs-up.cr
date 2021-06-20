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
    class_getter number : Int32 = 0 # number of Req-s in Requirements
    # getter reqs : Array(Req)

    # Initialize requirements object from *file* object

    def initialize(@file : File)
      @@number += 1
      # TODO: implement loading from YAML to reqs
    end

    def save!(dest)
      Nil
    end
  end

  # Requirement skeleton
  abstract class Req
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
    abstract def get_name

    # Return all available req versions
    abstract def versions

    # Update requirement version
    def update(ver : Versions = Versions::Latest) : Nil
      # TODO: implement version update
    end
  end

  # Requirement implementation for git
  class GitReq < Req
    @@scm = "git"
    @name : String = "FIXME"

    # @versions : Array(String)

    # fetch git versions
    def versions
      Nil # TODO: implement versions fetch
    end

    def get_name
      @name
    end
  end
end
