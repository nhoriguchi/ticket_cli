# coding: utf-8

require 'net/http'
require 'fileutils'

require_relative "./common/draft.rb"

require_relative "./redmine/cache.rb"
require_relative "./redmine/connection.rb"

require_relative "./redmine/list.rb"
require_relative "./redmine/project.rb"
require_relative "./redmine/show.rb"
require_relative "./redmine/new.rb"
require_relative "./redmine/edit.rb"
require_relative "./redmine/status.rb"
require_relative "./redmine/relation.rb"
require_relative "./redmine/wiki.rb"

class Redmine
  include Common

  include RedmineCache
  include RedmineConnection

  include RedmineCmdList
  include RedmineCmdProject
  include RedmineCmdShow
  include RedmineCmdNew
  include RedmineCmdEdit
  include RedmineCmdStatus
  include RedmineCmdRelation
  include RedmineCmdWiki

  def initialize options, cmd, args
    @options = options
    @serverconf = @options['servers'][@options[:server]]
    # pp @serverconf

    if @options["baseport"].to_i == 443
      @baseurl = "https://#{@serverconf["baseurl"]}/#{@serverconf["baseapi"]}"
    else
      @baseurl = "http://#{@serverconf["baseurl"]}:#{@serverconf["baseport"]}/#{@serverconf["baseapi"]}"
    end

    @cacheData = updateCache
    @options[:logger].debug("cache update done")
    # TODO: update metadata only when unknown key is found in ticket cache
    @metaCacheData = updateMetaCache
    @options[:logger].debug("metacache update done")

    if cmd == "list"
      list args
    elsif cmd == "project"
      project args
    elsif cmd == "show"
      show args
    elsif cmd == "edit"
      edit args
    elsif cmd == "new"
      new args
    elsif cmd == "status"
      status args
    elsif cmd == "relation"
      relation args
    elsif cmd == "wiki"
      wiki args
    elsif cmd == "sanitize"
    elsif cmd == "search"
    elsif cmd == "tree"
    elsif cmd == "file"
      attach_file args
    else
      puts "see `ticket -h`"
      exit
    end
  end

  def tree
  end
end
