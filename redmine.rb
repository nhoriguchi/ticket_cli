# coding: utf-8

require 'net/http'
require 'fileutils'

require_relative "./redmine/list.rb"
require_relative "./redmine/show.rb"
require_relative "./redmine/edit.rb"

class Redmine
  include RedmineCmdList
  include RedmineCmdShow
  include RedmineCmdEdit

  def initialize options
    @options = options

    if @options["baseport"].to_i == 443
      @baseurl = "https://" + @options["baseurl"]
    else
      @baseurl = "http://" + @options["baseurl"]
    end

    @cacheData = updateCache
    # TODO: update metadata only when unknown key is found in ticket cache
    @metaCacheData = updateMetaCache
  end

  def tree
  end

  private

  def parseDraftData draftFile
    afterEdit = File.read(draftFile).split("\n")
    afterMeta = []
    afterDescription = []
    metaline = 0

    afterEdit.each do |line|
      if metaline == 0
        if line == "---"
          metaline = 1
        else
          afterDescription << line
        end
      elsif metaline == 1
        if line == "---"
          metaline = 2
        else
          afterMeta << line
        end
      else
        afterDescription << line
      end
    end

    res = {"issue" => {}}
    res["issue"]["description"] = afterDescription.join("\n")

    afterMeta.each do |line|
      case line
      when /^id:\s*(.*?)\s*$/i
      when /^progress:\s*(.*?)\s*$/i
        res["issue"]["done_ratio"] = $1.to_i
      when /^status:\s*(.*?)\s*$/i
        tmp = @metaCacheData["issue_statuses"].find {|a| a["name"].downcase == $1.downcase}
        res["issue"]["status_id"] = tmp["id"] if tmp
      when /^subject:\s*(.*?)\s*$/i
        res["issue"]["subject"] = $1
      when /^project:\s*(.*?)\s*$/i
        tmp = @metaCacheData["projects"].find {|a| a["name"].downcase == $1.downcase}
        res["issue"]["project_id"] = tmp["id"] if tmp
      when /^type:\s*(.*?)\s*$/i
        tmp = @metaCacheData["trackers"].find {|a| a["name"].downcase == $1.downcase}
        res["issue"]["tracker_id"] = tmp["id"] if tmp
      when /^priority:\s*(.*?)\s*$/i
        tmp = @metaCacheData["issue_priorities"].find {|a| a["name"].downcase == $1.downcase}
        res["issue"]["priority_id"] = tmp["id"] if tmp
      when /^estimatedtime:\s*(.*?)\s*$/i
        res["issue"]["estimated_hours"] = $1.to_i
      when /^startdate:\s*(.*?)\s*$/i
        res["issue"]["start_date"] = $1 == "" ? nil : $1
      when /^duedate:\s*(.*?)\s*$/i
        res["issue"]["due_date"] = $1 == "" ? nil : $1
      when /^parent:\s*(.*?)\s*$/i
        res["issue"]["parent_issue_id"] = $1 == "null" ? nil : $1.to_i
      else
        raise "invalid metadata line #{line}"
      end
    end

    if metaline != 2
      raise "draft file is broken (should have two '---' separator lines), abort."
    end

    return res
  end

  def draftData id
    tmp = @cacheData[id]

    type = tmp["tracker"]["name"]
    priority = tmp["priority"]["name"]
    project = tmp["project"]["name"]
    status = tmp["status"]["name"]
    subject = tmp["subject"]
    description = tmp["description"]
    progress = tmp["done_ratio"]
    estimatedTime = tmp["estimated_hours"]
    startDate = tmp["start_date"]
    dueDate = tmp["due_date"]
    parent = tmp["parent"].nil? ? "null" : tmp["parent"]["id"]

    editdata = []
    editdata << "---"
    editdata << "ID: #{id}"
    editdata << "Progress: #{progress}"
    editdata << "Status: #{status}"
    editdata << "Subject: #{subject}"
    editdata << "Project: #{project}"
    editdata << "Type: #{type}"
    editdata << "Priority: #{priority}"
    editdata << "EstimatedTime: #{estimatedTime}"
    editdata << "StartDate: #{startDate}"
    editdata << "DueDate: #{dueDate}"
    editdata << "Parent: #{parent}"
    editdata << "---"
    editdata << description.gsub(/\r\n?/, "\n")

    return editdata
  end

  # update cache contents
  def updateCache
    cacheFile = @options["cacheDir"] + "/cacheData"
    if FileTest.exist? cacheFile
      cacheData = JSON.parse(File.read(cacheFile))
      cacheData, updated = updateLatestCache(cacheData)
      return cacheData if updated
    else
      FileUtils.mkdir_p(@options["cacheDir"])
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
      "key" => @options["token"]
    }

    __get_response "#{@baseurl}/issues.json", params
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
      "updated_on" => ">=#{max}",
      "key" => @options["token"]
    }

    issueAPI = "#{@baseurl}/issues.json"
    issues = __get_response_all issueAPI, params

    return cacheData, true if issues.size <= 1

    issues.each do |issue|
      cacheData[issue["id"]] = issue
    end
    return cacheData, false
  end

  def createFullCache
    params = {
      "status_id" => "*",
      "include" => "relations,attachments",
      "sort" => "updated_on:desc",
      "limit" => 100,
      "key" => @options["token"]
    }

    issueAPI = "#{@baseurl}/issues.json"
    issues = __get_response_all issueAPI, params

    cacheData = {}
    issues.each do |issue|
      cacheData[issue["id"]] = issue
    end
    return cacheData
  end

  def __get_response api, params
    uri = URI(api)
    uri.query = URI.encode_www_form(params)

    response = nil
    if @options["baseport"].to_i == 443
      require 'openssl'
      verify = OpenSSL::SSL::VERIFY_PEER
      verify = OpenSSL::SSL::VERIFY_NONE if @options[:insecure]

      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      :verify_mode => verify) do |http|
        request = Net::HTTP::Get.new uri
        response = http.request request
      end
    else # for http connection
      response = Net::HTTP.get_response(uri)
    end

    raise "http request failed." if response.code != "200"
    return JSON.load(response.body)
  end

  def __get_response_all api, params
    res = __get_response api, params

    issues = res["issues"]

    total = res["total_count"]
    if total > params["limit"]
      1.upto(total/params["limit"]) do |i|
        puts "#{i * params["limit"]} to #{total - (i) * params["limit"]}"
        # offset=$[i*step]&limit=$[limit-i*step]
        tmpres = __get_response api, params.merge({"offset" => i * params["limit"], "limit" => total - i * params["limit"]})
        issues += tmpres["issues"]
      end
    end
    return issues
  end

  def updateMetaCache
    metaCacheFile = @options["cacheDir"] + "/metaCacheData"
    if FileTest.exist? metaCacheFile
      metaCacheData = JSON.parse(File.read(metaCacheFile))
    else
      FileUtils.mkdir_p(@options["cacheDir"])
      metaCacheData = createMetaCache
      # TODO: persist metadata cache after implementing update detection
      # File.write(metaCacheFile, metaCacheData.to_json)
    end

    return metaCacheData
  end

  def createMetaCache
    params = {
      "limit" => 100,
      "key" => @options["token"]
    }

    metaCacheData = {}
    a = __get_response "#{@baseurl}/projects.json", params
    metaCacheData["projects"] = a["projects"]

    a = __get_response "#{@baseurl}/enumerations/issue_priorities.json", params
    metaCacheData["issue_priorities"] = a["issue_priorities"]

    a = __get_response "#{@baseurl}/trackers.json", params
    metaCacheData["trackers"] = a["trackers"]

    a = __get_response "#{@baseurl}/users.json", params
    metaCacheData["users"] = a["users"]

    a = __get_response "#{@baseurl}/issue_statuses.json", params
    metaCacheData["issue_statuses"] = a["issue_statuses"]

    # TODO: category and version as project-specific data

    return metaCacheData
  end
end
