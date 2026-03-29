#!/usr/bin/env crystal
# -*- mode: crystal; mode: view -*-
require "semantic_version"
require "yaml"
require "log"

module ReqsUp
  Log = ::Log.for(self)

  enum Versions
    Patch
    Minor
    Latest
  end

  enum YAMLFormat
    ReqList
    ReqCollections
    ReqRoles
  end

  # Describes requirements.yml object
  class Requirements
    Log = ::Log.for(self)
    include YAML::Serializable
    getter reqs : Array(Req) = [] of Req
    getter yaml : YAML::Any
    getter format : YAMLFormat
    private getter preserved_entries : Array(YAML::Any) = [] of YAML::Any

    def initialize(@file : File)
      @yaml = YAML.parse(@file.gets_to_end)
      @format = detect_format
      parse
      Log.trace { "Reqs: #{@reqs}" }
    end

    private def detect_format : YAMLFormat
      if @yaml.as_h? && @yaml.as_h.has_key?("collections")
        YAMLFormat::ReqCollections
      elsif @yaml.as_h? && @yaml.as_h.has_key?("roles")
        YAMLFormat::ReqRoles
      elsif @yaml.as_a?
        YAMLFormat::ReqList
      else
        raise "Unsupported YAML format: expected array or object with 'collections' or 'roles' key"
      end
    end

    private def parse
      case @format
      when YAMLFormat::ReqList
        parse_req_list
      when YAMLFormat::ReqCollections
        parse_collections
      when YAMLFormat::ReqRoles
        parse_roles
      end
    end

    private def parse_req_list
      @yaml.as_a.each do |y|
        Log.debug { "#{y}" }
        next unless y["src"]? || y["source"]?
        case y["scm"]?.try(&.as_s)
        when "git"
          @reqs << GitReq.new(y)
        else
          @reqs << DefaultReq.new(y)
        end
      end
    end

    private def parse_collections
      collections = @yaml["collections"].as_a
      collections.each do |y|
        Log.debug { "#{y}" }
        if y["source"]? || y["src"]?
          case y["type"]?.try(&.as_s)
          when "git"
            @reqs << GitReq.new(y)
          else
            @reqs << DefaultReq.new(y)
          end
        else
          @preserved_entries << y
        end
      end
    end

    private def parse_roles
      roles = @yaml["roles"].as_a
      roles.each do |y|
        Log.debug { "#{y}" }
        next unless y["src"]? || y["source"]?
        case y["scm"]?.try(&.as_s)
        when "git"
          @reqs << GitReq.new(y)
        else
          @reqs << DefaultReq.new(y)
        end
      end
    end

    # Return YAML dump of internal state
    def dump : String
      case @format
      when YAMLFormat::ReqList
        YAML.dump(@reqs) + "...\n"
      when YAMLFormat::ReqCollections
        collections_yaml = @reqs.map(&.original_yaml) + @preserved_entries
        YAML.dump({"collections" => collections_yaml})
      when YAMLFormat::ReqRoles
        roles_yaml = @reqs.map(&.original_yaml)
        YAML.dump({"roles" => roles_yaml})
      else
        raise "Unknown format"
      end
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
      src_val = req["src"]?.try(&.as_s?) || req["source"]?.try(&.as_s?)
      @src = src_val || raise "Missing src/source key"
      if req["name"]?
        @name = req["name"].as_s
      end
      if req["version"]?
        @version = req["version"].as_s
      end
      @scm = req["scm"]?.try(&.as_s) || req["type"]?.try(&.as_s)
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

    # Update requirement version, returns final version and explanation
    def update(ver : Versions = Versions::Latest) : String | Nil
      Log.debug { "Updating req #{self}" }
      current : SemanticVersion | Nil = nil
      begin
        current = SemanticVersion.parse(@version.not_nil!)
      rescue ArgumentError
        Log.debug { "#{@version} is not semver, skipping" }
        return
      rescue NilAssertionError
        Log.debug { "No version defined, skipping" }
        return
      end
      return unless current

      Log.debug { "Current version: #{@version}" }
      tags = versions

      selected = select_version(tags, current, ver)
      if selected
        @version = selected.version.to_s
        explanation = explain_selection(ver, current, selected.version)
        Log.info { "#{@name || @src}: #{current} → #{@version} (#{explanation})" }
        return @version
      else
        case ver
        when Versions::Patch
          Log.warn { "no suitable versions found for '#{@name || @src}' within patch version (current: #{current})" }
        when Versions::Minor
          Log.warn { "no suitable versions found for '#{@name || @src}' within minor version (current: #{current})" }
        when Versions::Latest
          return @version
        end
        return nil
      end
    end

    private def select_version(tags : Array(String), current : SemanticVersion, ver : Versions) : Selection | Nil
      stable_tags = tags.compact_map do |t|
        begin
          v = SemanticVersion.parse(t)
          v.prerelease.to_s.empty? ? Selection.new(t, v) : nil
        rescue ArgumentError
          Log.warn { "skipping non-semver tag '#{t}' for repository '#{@src}'" }
          nil
        end
      end

      return nil if stable_tags.empty?

      case ver
      when Versions::Latest
        max = stable_tags.max_by(&.version)
        max if max.version > current
      when Versions::Minor
        candidates = stable_tags.select { |c| c.version.major == current.major }
        return nil if candidates.empty?
        max = candidates.max_by(&.version)
        max if max.version > current
      when Versions::Patch
        candidates = stable_tags.select { |c| c.version.major == current.major && c.version.minor == current.minor }
        return nil if candidates.empty?
        max = candidates.max_by(&.version)
        max if max.version > current
      end
    end

    private struct Selection
      getter tag : String
      getter version : SemanticVersion

      def initialize(@tag, @version)
      end
    end

    private def explain_selection(ver : Versions, current : SemanticVersion, selected : SemanticVersion) : String
      explanation = case ver
                    when Versions::Latest
                      "latest"
                    when Versions::Minor
                      "max minor version for #{current.major}.x"
                    when Versions::Patch
                      "max patch version for #{current.major}.#{current.minor}.x"
                    end
      explanation || "unknown"
    end
  end

  # Requirement implementation for git
  class GitReq < Req
    Log = ::Log.for(self)
    getter original_yaml : YAML::Any

    def initialize(req : YAML::Any)
      super(req)
      @original_yaml = req
    end

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
        result << tag.sub(/^v/i, "")
      end
      status = process.wait
      if !status.success?
        Log.error { "Running \"#{proccmd}\" failed" }
      end
      result
    end
  end

  # Requirement implementation for non-git sources
  class DefaultReq < Req
    getter original_yaml : YAML::Any

    def initialize(req : YAML::Any)
      super(req)
      @original_yaml = req
    end

    def versions : Array(String)
      v = @version
      v ? [v] : [] of String
    end
  end
end
