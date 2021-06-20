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
    getter reqs : Array(Req)

    # Initialize requirements object from *file* object
    def initialize(@file : File)
      @@number += 1
      # TODO: implement loading from YAML to reqs
    end
  end

  # Requirement skeleton
  abstract class Req
    property src : String
    property name : String # TODO: initialize if undefined
    property version : String = "master"
    getter scm : String = "git"

    def initialize(src : String, **attrs)
      # TODO: load attributes
    end

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
    @versions : Array(String)

    # fetch git versions
    def versions
      Nil # TODO: implement versions fetch
    end
  end
end
