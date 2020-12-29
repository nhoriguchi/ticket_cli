# coding: utf-8
# チケットサーバが Redmine 場合に固有のコードを実装する。

require 'net/http'
require 'fileutils'

class Redmine
  def initialize args
    @config = args
    if @config["baseport"].to_i == 443
      @baseurl = "https://" + @config["baseurl"]
    else
      @baseurl = "http://" + @config["baseurl"]
    end

    @cacheData = updateCache
  end

  def list    
    # raise
    keys = @cacheData.keys.sort {|a, b| b.to_i <=> a.to_i}
    keys.each do |k|
      c = @cacheData[k]
      printf "%-4d %3d %-10s %-14s (%s) %s\n", k, c["done_ratio"], c["tracker"]["name"], c["status"]["name"], c["project"]["name"], c["subject"]
    end
  end

  def show id
    raise "issue #{id} not found" if @cacheData[id].nil?
    tmp = draftData id
    puts tmp.join("\n")
  end

  def edit id
    raise "issue #{id} not found" if @cacheData[id].nil?
    tmp = draftData id
    puts tmp.join("\n")

    editDir = "#{@config["cacheDir"]}/edit"
    FileUtils.mkdir_p(editDir)
    draftFile = "#{editDir}/#{id}.md"
    File.write(draftFile, tmp.join("\n"))
    
    # system "#{ENV["EDITOR"]} #{draftFile}"

    # TODO: check diff

    parseDraftData draftFile
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
    pp afterMeta
    pp afterDescription
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

    editdata = ["---"]
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
    editdata << ["---"]
    editdata << description.gsub(/\r\n?/, "\n")

    return editdata
  end

  # update cache contents
  def updateCache
    cacheFile = @config["cacheDir"] + "/cacheData"
    if FileTest.exist? cacheFile
      cacheData = JSON.parse(File.read(cacheFile))
      cacheData, updated = updateLatestCache(cacheData)
      return cacheData if updated
    else
      FileUtils.mkdir_p(@config["cacheDir"])
      cacheData = createFullCache
    end

    File.write(cacheFile, cacheData.to_json)
    return cacheData
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
      "key" => @config["token"]
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
      "key" => @config["token"]
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
    response = Net::HTTP.get_response(uri)
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
end
