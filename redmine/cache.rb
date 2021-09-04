# coding: utf-8

module RedmineCache
  private

  # update cache contents
  def updateCache
    cacheFile = @options["cachedir"] + "/cacheData"
    if FileTest.exist? cacheFile
      @cacheData = cacheData = JSON.parse(File.read(cacheFile))
      cacheData, updated = updateLatestCache(cacheData)
      return cacheData if updated == false
    else
      FileUtils.mkdir_p(@options["cachedir"])
      cacheData = createFullCache
    end

    File.write(cacheFile, cacheData.to_json)
    return cacheData
  end

  def updateCacheIssue id
    params = {
      "issue_id" => id,
      "include" => "relations,attachments",
      "status_id" => "*",
      "key" => @serverconf["token"]
    }

    response = __get_response "#{@baseurl}/issues.json", params
    return response["issues"][0]
  end

  def updateLatestCache cacheData
    max = "1000-01-01T00:00:00Z"
    cacheData.each do |k, v|
      max = v["updated_on"] if max < v["updated_on"]
    end

    params = {
      "status_id" => "*",
      "include" => "relations,attachments",
      "sort" => "updated_on:desc",
      "limit" => 100,
      "updated_on" => "><#{max}",
      "key" => @serverconf["token"]
    }

    issueAPI = "#{@baseurl}/issues.json"
    issues = __get_response_all issueAPI, params

    return cacheData, false if issues.size < 1

    issues.each do |issue|
      cacheData[issue["id"].to_s] = issue
    end
    return cacheData, true
  end

  def createFullCache
    params = {
      "status_id" => "*",
      "include" => "relations,attachments",
      "sort" => "updated_on:desc",
      "limit" => 100,
      "key" => @serverconf["token"]
    }

    issueAPI = "#{@baseurl}/issues.json"
    issues = __get_response_all issueAPI, params

    cacheData = {}
    issues.each do |issue|
      cacheData[issue["id"]] = issue
    end
    return cacheData
  end

  def updateMetaCache force=false
    metaCacheFile = @options["cachedir"] + "/metaCacheData"
    if FileTest.exist? metaCacheFile and force == false
      @metaCacheData = JSON.parse(File.read(metaCacheFile))
    else
      FileUtils.mkdir_p(@options["cachedir"])
      @metaCacheData = createMetaCache
    end

    File.write(metaCacheFile, @metaCacheData.to_json)
  end

  def asyncUpdateMetaCache
    Thread.start do
      updateMetaCache true
    end
  end

  def createMetaCache
    params = {
      "limit" => 100,
      "key" => @serverconf["token"]
    }

    metaCacheData = {}
    a = __get_response "#{@baseurl}/projects.json", params
    metaCacheData["projects"] = a["projects"]

    a = __get_response "#{@baseurl}/enumerations/issue_priorities.json", params
    metaCacheData["issue_priorities"] = a["issue_priorities"]

    a = __get_response "#{@baseurl}/trackers.json", params
    metaCacheData["trackers"] = a["trackers"]

    begin
      if @serverconf["setting"]["userlist"] == true
        a = __get_response "#{@baseurl}/users.json", params
        metaCacheData["users"] = a["users"]
      end
    rescue
    end

    a = __get_response "#{@baseurl}/issue_statuses.json", params
    metaCacheData["issue_statuses"] = a["issue_statuses"]

    # TODO: category and version as project-specific data
    return metaCacheData
  end

  def is_status_closed status
    tmp = parse_statusspec status
    tmp = @metaCacheData["issue_statuses"].find {|elm| elm["id"] == tmp}
    tmp["is_closed"]
  end

  def default_priority
    @metaCacheData["issue_priorities"].find {|elm| elm["is_default"]}["id"]
  end

  def parse_statusspec statusspec
    tmp = @metaCacheData["issue_statuses"].find {|elm| elm["id"] == statusspec}
    return statusspec if tmp
    reg = Regexp.new(statusspec, Regexp::IGNORECASE)
    tmp = @metaCacheData["issue_statuses"].find {|elm| elm["name"] =~ reg}
    return tmp["id"]
  end

  def parse_trackerspec trackerspec
    tmp = @metaCacheData["trackers"].find {|elm| elm["id"] == trackerspec}
    return trackerspec if tmp
    reg = Regexp.new(trackerspec, Regexp::IGNORECASE)
    tmp = @metaCacheData["trackers"].find {|elm| elm["name"] =~ reg}
    return tmp["id"]
  end

  def parse_userspec userspec
    tmp = @metaCacheData["users"].find {|elm| elm["id"].to_s == userspec}
    return userspec if tmp
    tmp = @metaCacheData["users"].find {|elm| elm["login"] == userspec}
    return tmp["id"] if tmp
    return ""
  end

  def parse_projectspec projectspec
    tmp = @metaCacheData["projects"].find {|elm| elm["id"].to_s == projectspec}
    return projectspec if tmp
    reg = Regexp.new(projectspec, Regexp::IGNORECASE)
    tmp = @metaCacheData["projects"].find {|elm| elm["identifier"].to_s =~ reg}
    return tmp["id"] if tmp
    tmp = @metaCacheData["projects"].find {|a| a["name"] =~ reg}
    return tmp["id"] if tmp
    return ""
  end

  def parse_date datespec
    return "" if datespec == ""
    if datespec =~ /^([\+\-]\d+)$/ or datespec == "0"
      return (Time.now + (datespec.to_i) * 86400).strftime("%Y-%m-%d")
    end
    tmp = DateTime.parse(datespec)
    tmp.strftime("%Y-%m-%d")
  end

  def status_name statusspec
    stid = parse_statusspec statusspec
    @metaCacheData["issue_statuses"].find {|a| a["id"] == stid}["name"]
  end

  def tracker_name trackerspec
    trid = parse_trackerspec trackerspec
    @metaCacheData["trackers"].find {|a| a["id"] == trid}["name"]
  end

  def user_name userspec
    usid = parse_userspec userspec
    @metaCacheData["users"].find {|a| a["id"] == usid}["login"]
  end

  def project_name projectspec
    begin
      pjid = parse_projectspec projectspec
      @metaCacheData["projects"].find {|a| a["id"].to_s == pjid}["name"]
    rescue
      return ""
    end
  end
end
