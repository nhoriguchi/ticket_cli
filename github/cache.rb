# coding: utf-8
module GitHubCache
  def updateMetaCache force=true
    metaCacheFile = @options["cachedir"] + "/metaCacheData"
    if FileTest.exist? metaCacheFile
      @metaCacheData = JSON.parse(File.read(metaCacheFile))
      # updated = updateLatestMetaCache
      return
      return if updated == false
    else
      FileUtils.mkdir_p(@options["cachedir"])
      createMetaCache
    end

    File.write(metaCacheFile, @metaCacheData.to_json)
  end

  # https://docs.gitlab.com/ee/api/projects.html
  def createMetaCache
    params = {
      # TODO: all
      "limit" => 100,
      "key" => @serverconf["token"],
    }

    @metaCacheData = {"reposid" => {}, "reposname" => {}}
    a = __get_response "#{@baseurl}/users/#{@serverconf["user"]}/repos", params
    a.each do |proj|
      @metaCacheData["reposid"][proj["id"]] = proj
      @metaCacheData["reposname"][proj["full_name"]] = proj["id"]
    end
  end

  def updateLatestMetaCache
    max = Time.new(1970)

    @metaCacheData["projects"].each do |k, v|
      tmp = Time.parse(v["last_activity_at"])
      max = tmp if max < tmp
    end

    params = {
      "limit" => 100,
      "last_activity_after" => (max + 1).iso8601(0),
      "private_token" => @serverconf["token"],
    }

    a = __get_response "#{@baseurl}/projects", params
    return false if a.size < 1
    puts "-- updated #{a.size} projects"
    a.each do |proj|
      @metaCacheData["projects"][proj["id"]] = proj
    end
    return true
  end

  def updateSingleMetaCache projname
    params = {}
    # params = {:client_id => @serverconf["user"], :oauth_token => @serverconf["token"]}
    a = __get_response "#{@baseurl}/repos/#{projname}", params
    @metaCacheData["reposid"][a["id"]] = a
    @metaCacheData["reposname"][projname] = a["id"]

    metaCacheFile = @options["cachedir"] + "/metaCacheData"
    File.write(metaCacheFile, @metaCacheData.to_json)
    # pjid = @metaCacheData["reposname"][projname]
    # if pjid.nil?
    #   # create new cache
    # else
    #   # update the found cache
    #   proj = @metaCacheData["reposid"][pjid]
    # end
    # @metaCacheData["reposid"][proj["id"]] = proj
  end

  def updateSingleCache projname
    params = {}
    pjid = @metaCacheData["reposname"][projname]
    @cacheData[pjid] = {}
    issues = __get_response "#{@baseurl}/repos/#{projname}/issues", params
    issues.each do |issue|
      @cacheData[pjid][issue["number"].to_s] = issue
    end
    cacheFile = @options["cachedir"] + "/cacheData"
    File.write(cacheFile, @cacheData.to_json)
  end

  def updateCache
    cacheFile = @options["cachedir"] + "/cacheData"
    if FileTest.exist? cacheFile
      @cacheData = cacheData = JSON.parse(File.read(cacheFile))
      # updated = updateLatestCache
      return
      return if updated == false
    else
      FileUtils.mkdir_p(@options["cachedir"])
      @cacheData = createFullCache
    end

    File.write(cacheFile, @cacheData.to_json)
    return
  end

  def createFullCache
    params = {}
    cacheData = {}
    @metaCacheData["repos"].keys.each do |pjid|
      issueAPI = "#{@baseurl}/repos/#{@metaCacheData["repos"][pjid]["full_name"]}/issues"
      issues = __get_response issueAPI, params

      cacheData[pjid.to_s] = {}
      issues.each do |issue|
        cacheData[pjid.to_s][issue["number"].to_s] = issue
      end
    end
    return cacheData
  end

  def updateLatestCache
    updated = false
    @metaCacheData["projects"].keys.each do |pjid|
      max = Time.new(1970)
      last_activity = @metaCacheData["projects"][pjid]["last_activity_at"]
      last_activity = Time.parse(last_activity)
      params = {
        "updated_after" => (last_activity + 1).iso8601(0),
        "private_token" => @serverconf["token"],
      }

      issues = __get_response "#{@baseurl}/projects/#{pjid}/issues", params
      issues.each do |issue|
        @cacheData[pjid][issue["iid"].to_s] = issue
      end
      updated = true if issues.size > 0
    end
    return updated
  end

  def updateNoteCache
    noteCacheFile = @options["cachedir"] + "/noteCacheData"
    if FileTest.exist? noteCacheFile
      @noteCacheData = noteCacheData = JSON.parse(File.read(noteCacheFile))
      # noteCacheData, updated = updateLatestNoteCache(noteCacheData)
      return noteCacheData # if updated == false
    else
      FileUtils.mkdir_p(@options["cachedir"])
      # @noteCacheData = noteCacheData = createFullNoteCache
      noteCacheData = {}
    end

    File.write(noteCacheFile, noteCacheData.to_json)
    return noteCacheData
  end

  def updateSingleNoteCache pjid, iid
    # pjid, iid = id.split("-")
    issue = @cacheData[pjid][iid]

    # 必要判定、issue の updated_at は、note の uppdated_at
    # と完全には一致しない。floor を用いて小数点以下を切り捨てる。
    tstamp1 = Time.parse(issue["updated_at"]).floor

    if @noteCacheData[pjid] and @noteCacheData[pjid][iid]
      if @noteCacheData[pjid][iid].size > 0
        tstamp2 = Time.parse(@noteCacheData[pjid][iid][0]["updated_at"]).floor
      end
    end

    if tstamp2.nil? or tstamp2 < tstamp1
      # no notes
      if @cacheData[pjid][iid]["comments"] > 0
        __updateSingleNoteCache pjid, iid
      end
    end
  end

  def __updateSingleNoteCache pjid, iid
    noteCacheFile = @options["cachedir"] + "/noteCacheData"
    projname = @metaCacheData["reposid"][pjid]["full_name"]
    # params = {:client_id => @serverconf["user"], :client_token => @serverconf["token"]}
    params = {}
    notesAPI = "#{@baseurl}/repos/#{projname}/issues/#{iid}/comments"
    notes = __get_response notesAPI, params
    # puts "notes = #{notes}"

    @noteCacheData[pjid] = {} if @noteCacheData[pjid].nil?
    @noteCacheData[pjid][iid] = notes
    File.write(noteCacheFile, @noteCacheData.to_json)
    # pp notes
  end

  def createFullNoteCache
    params = {}
    cacheData = {}
    @metaCacheData["projects"].keys.each do |pjid|
      issueAPI = "#{@baseurl}/projects/#{pjid}/issues"
      issues = __get_response issueAPI, params

      cacheData[pjid.to_s] = {}
      issues.each do |issue|
        cacheData[pjid.to_s][issue["iid"]] = issue
      end
    end
    return cacheData
  end
end
