#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "semantic_version"
require "yaml"

module ReqsUp
  # Describes requirements.yaml object
  class Requirements
    # Initialize requirements object from *file* path
    def initialize(@file : Path)
    end
  end
end
