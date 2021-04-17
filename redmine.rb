# coding: utf-8

require 'net/http'
require 'fileutils'

require_relative "./redmine/cache.rb"
require_relative "./redmine/connection.rb"

require_relative "./redmine/list.rb"
require_relative "./redmine/show.rb"
require_relative "./redmine/edit.rb"

class Redmine
  include RedmineCache
  include RedmineConnection

  include RedmineCmdList
  include RedmineCmdShow
  include RedmineCmdEdit

  def initialize options
    @options = options
    @serverconf = @options['servers'][@options[:server]]
    # pp @serverconf

    if @options["baseport"].to_i == 443
      @baseurl = "https://#{@serverconf["baseurl"]}/#{@serverconf["baseapi"]}"
    else
      @baseurl = "https://#{@serverconf["baseurl"]}:#{@serverconf["baseport"]}/#{@serverconf["baseapi"]}"
    end

    @cacheData = updateCache
    # TODO: update metadata only when unknown key is found in ticket cache
    @metaCacheData = updateMetaCache
  end

  def tree
  end
end
