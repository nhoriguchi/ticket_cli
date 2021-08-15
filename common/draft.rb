module Common
  def prepareDraft path, data
    return if File.exist? path
    dir = File.dirname path
    FileUtils.mkdir_p(dir)
    draftFile = path
    draftFileOrig = path + ".orig"
    File.write(draftFile, data)
    File.write(draftFileOrig, data)
  end

  def editDraft path
    draftFile = path
    draftFileOrig = path + ".orig"
    system "#{ENV["EDITOR"]} #{draftFile}"
    ret = system("diff #{draftFile} #{draftFileOrig} > /dev/null")
    if ret == true
      puts "no change on draft file."
      return false
    end
    return true
  end

  def cleanupDraft path
    File.delete(path)
    File.delete(path + ".orig")
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
end
