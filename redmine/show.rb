# coding: utf-8

module RedmineCmdShow
  def show id
    raise "issue #{id} not found" if @cacheData[id].nil?
    a = updateCacheIssue id
    @cacheData[id] = a["issues"][0]
    tmp = draftData id
    puts tmp.join("\n")
  end
end
