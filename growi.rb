# coding: utf-8

require 'net/http'
require 'fileutils'
require 'growi-client'

require_relative "./common/draft.rb"

require_relative "./growi/cache.rb"
require_relative "./redmine/connection.rb"

require_relative "./growi/list.rb"
require_relative "./growi/show.rb"
require_relative "./growi/edit.rb"
require_relative "./growi/status.rb"

class Growi
  include Common

  include RedmineConnection
  include GrowiCache

  include GrowiCmdList
  include GrowiCmdShow
  include GrowiCmdEdit
  include GrowiCmdStatus

  def initialize options, cmd, args
    @options = options
    @serverconf = @options['servers'][@options[:server]]

    if @options["baseport"].to_i == 443
      @baseurl = "https://#{@serverconf["baseurl"]}/#{@serverconf["baseapi"]}"
    else
      @baseurl = "http://#{@serverconf["baseurl"]}:#{@serverconf["baseport"]}/#{@serverconf["baseapi"]}"
    end
    @baseurl += "_api"

    @gclient = GrowiClient.new(growi_url: @baseurl, access_token: @serverconf["token"])
    @cacheData = updateCache
    @options[:logger].debug("cache update done")
    # TODO: update metadata only when unknown key is found in ticket cache
    updateMetaCache
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
      file args
    else
      puts "see `ticket -h`"
      exit
    end
  end

  def tree
  end
end
