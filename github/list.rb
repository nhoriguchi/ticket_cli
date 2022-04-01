# coding: utf-8

require "date"

module GitHubCmdList
  def list args

    projs = args
    proj = args[0]

    updateSingleMetaCache proj
    updateSingleCache proj

    if @metaCacheData["reposname"][proj].nil?
      raise "project #{proj} not found in cache"
    end

    # p "#{@baseurl}/repos/#{proj}/pages"
    # wikis = __get_response "#{@baseurl}/repos/#{proj}/pages", {}
    # pp wikis

    pjid = @metaCacheData["reposname"][proj]
    @cacheData[pjid].each do |iid, issue|
      puts "#{iid}\t#{issue["state"]}\t#{issue["comments"]}\t#{issue["title"]}"
    end
  end
end
