# coding: utf-8

module RedmineCmdEdit
  def edit args
    id = args[0]
    raise "issue #{id} not found" if @cacheData[id].nil?
    updateCacheIssue id

    # TODO: move to proper place
    editDir = "#{@options["cachedir"]}/edit"
    FileUtils.mkdir_p(editDir)
    extension = @serverconf["format"]
    draftFile = "#{editDir}/#{id}.#{extension}"
    draftFileOrig = "#{editDir}/.#{id}.#{extension}"
    draftFileBackup = "#{editDir}/.#{id}.backup.#{extension}"
    File.write(draftFile, draftData(id).join("\n"))

    # TODO: update metadata cache asynchronously here
    # TODO: calculate duration of editing
    # TODO: ask yes/no or progress update
    # TODO: conflict check
    # TODO: save edited draft when upload failed

    t1 = Time.now
    system "cp #{draftFile} #{draftFileOrig} ; #{ENV["EDITOR"]} #{draftFile} ; cp #{draftFile} #{draftFileBackup}"
    ret = system("diff #{draftFile} #{draftFileOrig} > /dev/null")
    if ret == true
      puts "no change on draft file."
      return
    end
    t2 = Time.now

    uploadData, duration = parseDraftData draftFile
    uploadIssue id, uploadData

    duration = ((t2 - t1).to_i / 60) if duration.nil?
    createTimeEntry id, duration
  end

  def uploadIssue id, draftData
    uri = URI("#{@baseurl}/issues/#{id}.json")
    response = put_issue uri, draftData

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
  end

  private

  # TODO: support adding comments
  def createTimeEntry id, duration
    if duration >= 5
      min = duration % 60
      hour = duration / 60

      tmpjson = {
        "time_entry" => {
          "issue_id" => id,
          "hours" => "%d:%02d" % [hour, min],
          "comments" => ""
        }
      }

      uri = URI("#{@baseurl}/time_entries.json")
      response = post_time_entry uri, tmpjson
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        puts "create time entry done"
      else
        raise response.value
      end
    end
  end

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

    duration = nil

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
      when /^duration:\s*(.*?)\s*$/i
        tmp = $1
        if tmp =~ /(\d+):(\d{2})/
          duration = $1.to_i * 60 + $2.to_i
        else
          duration = tmp.to_i
        end
      else
        raise "invalid metadata line #{line}"
      end
    end

    if metaline != 2
      raise "draft file is broken (should have two '---' separator lines), abort."
    end

    return res, duration
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
    editdata << "Duration:"
    editdata << "---"
    editdata << description.gsub(/\r\n?/, "\n")

    return editdata
  end
end
