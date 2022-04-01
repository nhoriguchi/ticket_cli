# coding: utf-8

require "date"

module GitLabCmdList
  def list args

    projs = args

    @cacheData.each do |pjid, issues|
      next if (not projs.empty?) and (not projs.include? pjid)

      baseurl = @metaCacheData["projects"][pjid]["web_url"]

      # pp issues
      issues.each do |iid, issue|
        tstamp = Time.parse(issue["updated_at"]).strftime("%Y-%m-%d %H:%M:%S")
        printf "#{pjid}-#{iid}\t#{issue["state"]}\t#{tstamp}\t#{issue["title"]}\n"
      end

      updateSingleWikiCache pjid
      @wikiCacheData[pjid].each_with_index do |wiki, i|
        printf "#{pjid}-w#{i}\t#{wiki["title"]}\t#{baseurl}/-/wikis/#{wiki["slug"]}\n"
      end
    end

    wikiCacheFile = @options["cachedir"] + "/wikiCacheData"
    File.write(wikiCacheFile, @wikiCacheData.to_json)
  end
end
