# coding: utf-8

module RedmineCache
  private

  # update cache contents
  def updateCache
    cacheFile = @options["cachedir"] + "/cacheData"
    if FileTest.exist? cacheFile
      cacheData = JSON.parse(File.read(cacheFile))
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
    @cacheData[id] = response["issues"][0]
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

  def updateMetaCache
    metaCacheFile = @options["cachedir"] + "/metaCacheData"
    if FileTest.exist? metaCacheFile
      metaCacheData = JSON.parse(File.read(metaCacheFile))
      return metaCacheData
    else
      FileUtils.mkdir_p(@options["cachedir"])
      metaCacheData = createMetaCache
      # TODO: persist metadata cache after implementing update detection
      # File.write(metaCacheFile, metaCacheData.to_json)
    end

    File.write(metaCacheFile, metaCacheData.to_json)
    return metaCacheData
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

    if @serverconf["setting"]["userlist"] == true
      a = __get_response "#{@baseurl}/users.json", params
      metaCacheData["users"] = a["users"]
    end

    a = __get_response "#{@baseurl}/issue_statuses.json", params
    metaCacheData["issue_statuses"] = a["issue_statuses"]

    # TODO: category and version as project-specific data
    return metaCacheData
  end

  def is_status_closed status
    tmp = @metaCacheData["issue_statuses"].find {|elm| elm["name"] == status}
    tmp["is_closed"]
  end

  def tracker_name_to_id tracker
    tmp = @metaCacheData["trackers"].find {|elm| elm["name"] == tracker}
    tmp["id"]
  end

  def status_name_to_id status
    tmp = @metaCacheData["issue_statuses"].find {|elm| elm["name"] == status}
    tmp["id"]
  end
end
