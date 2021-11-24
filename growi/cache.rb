# coding: utf-8
require_relative "../common/connection.rb"

module GrowiCache
  include Connection

  def updateCache
    cacheFile = @options["cachedir"] + "/cacheData"

    res = `curl -s "#{@baseurl}/pages.list?path=/"`
    response = JSON.load(res)
    raise "fail" if response["ok"] != true
    pages = response["pages"]

    # if FileTest.exist? cacheFile
    #   @cacheData = cacheData = JSON.parse(File.read(cacheFile))
    #   cacheData, updated = updateLatestCache(cacheData)
    #   return cacheData if updated == false
    # else
      FileUtils.mkdir_p(@options["cachedir"])
      @cacheData = cacheData = createFullCache pages
    # end

    File.write(cacheFile, cacheData.to_json)
    return cacheData
  end

  def updateMetaCache force=false
  end

  def updateWikiCache pages=[]
    cacheFile = @options["cachedir"] + "/cacheData"
    wikiCacheFile = @options["cachedir"] + "/wikiCacheData"

    pages.each do |page|
      if @cacheData.keys.include? page
        @cacheData[page]["page"] = getWikiData page
      end
    end

    File.write(cacheFile, @cacheData.to_json)
    # File.write(wikiCacheFile, @wikiCacheData.to_json)
  end

  private

  def createFullCache pages
    tmp = {}
    pages.each do |page|
      tmp[page["path"]] = page
    end
    return tmp
  end

  def __updateWikiCache
  end

  def getWikiData path
    res = `curl -s #{@baseurl}/pages.get?path=#{path}&access_token=#{@serverconf["token"]}`
    response = JSON.load(res)
    raise "fail" if response["ok"] != true
    page = response["page"]
    return page

    # pp path
    # pp @cacheData[path]
    pp response
    raise if response["ok"] != true
    return response["page"]
  end
end
