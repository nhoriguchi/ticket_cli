# coding: utf-8

# TODO: use gitlab ruby gem

require 'net/http'
require 'fileutils'

require_relative "../common/draft.rb"

require_relative "./cache.rb"
require_relative "./connection.rb"
#
require_relative "./list.rb"
require_relative "./project.rb"
require_relative "./show.rb"
# require_relative "../redmine/new.rb"
require_relative "./edit.rb"
require_relative "../redmine/status.rb"
# require_relative "../redmine/relation.rb"
# require_relative "../redmine/wiki.rb"
# require_relative "../redmine/file.rb"

class GitLab
  include Common

  include GitLabCache
  include GitLabConnection

  include GitLabCmdList
  include GitLabCmdProject
  include GitLabCmdShow
  # include RedmineCmdNew
  include GitLabCmdEdit
  include RedmineCmdStatus
  # include RedmineCmdRelation
  # include RedmineCmdWiki
  # include RedmineCmdFile

  def initialize options, cmd, args
    @options = options
    @serverconf = @options['servers'][@options[:server]]
    # pp @serverconf

    if @options["baseport"].to_i == 443
      @baseurl = "https://#{@serverconf["baseurl"]}/#{@serverconf["baseapi"]}"
    else
      @baseurl = "http://#{@serverconf["baseurl"]}:#{@serverconf["baseport"]}/#{@serverconf["baseapi"]}"
    end

    # TODO: update metadata only when unknown key is found in ticket cache
    updateMetaCache
    @options[:logger].debug("metacache update done")
    begin
      updateCache
    rescue
      puts "updateCache failed, maybe connection is temporary unavailable now."
    end
    @options[:logger].debug("cache update done")
    begin
      @noteCacheData = updateNoteCache
    rescue
      puts "updateNoteCache failed, maybe connection is temporary unavailable now."
    end
    @options[:logger].debug("note cache update done")

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
