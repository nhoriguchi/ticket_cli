# coding: utf-8
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
    # raise "editor #{@options[:editor]} not found" # if not File.exist? @options[:editor]
    system "#{@options[:editor]} #{draftFile}"
    return if ! File.exist? draftFileOrig
    tmp = Diffy::Diff.new(File.read(draftFileOrig), File.read(draftFile), :context => 3).to_s.split("\n")
    tmp.delete("\\ No newline at end of file")
    if tmp.empty?
      puts "no change on draft file."
      return false
    end
    return true
  end

  def draftPath id
    "#{@options["cachedir"]}/edit/#{id}.#{@serverconf["format"]}"
  end

  def draftOrigPath id
    "#{@options["cachedir"]}/edit/#{id}.#{@serverconf["format"]}.orig"
  end

  def draftConflictPath id
    "#{@options["cachedir"]}/edit/#{id}.#{@serverconf["format"]}.conflictcheck"
  end

  def editDrafts ids
    # raise "editor #{@options[:editor]} not found" # if not File.exist? @options[:editor]
    puts "#{@options[:editor]} #{ids.map do |id| draftPath id ; end.join(" ")}"
    system "#{@options[:editor]} #{ids.map do |id| draftPath id ; end.join(" ")}"
  end

  def diffDrafts ids
    tmp = []
    ids.each do |id|
      next if id_type(id) == "new"
      tmp << "#################################### #{id} ####################################"
      tmpdiff = Diffy::Diff.new(File.read(draftOrigPath(id)), File.read(draftPath(id)), :context => 3).to_s.split("\n")
      tmpdiff.delete("\\ No newline at end of file")
      if ! tmpdiff.empty?
        tmp << tmpdiff
      end
    end
    if tmp.empty?
      puts "no change on draft files"
      return false
    else
      puts tmp.join("\n")
      return true
    end
  end

  def cleanupDraft path
    delDir = "#{@options["cachedir"]}/deleted_drafts"
    FileUtils.mkdir_p(delDir)
    FileUtils.mv([path], delDir) if File.exist? path
    FileUtils.mv([path + ".orig"], delDir) if File.exist?(path + ".orig")
    FileUtils.rm([path + ".conflictcheck", path + ".conflictcheck.orig"], :force => true)
  end

  def cancelDrafts ids
    ids.each do |id|
      cleanupDraft draftPath(id)
    end
  end

  def saveDrafts ids, t1
    ids.each do |id|
      if id_type(id) == "ticket"
        saveDraftDuration draftPath(id), ((Time.now - t1).to_i / 60)
      end
    end
  end

  # TODO: Redmine ?????????
  def parseDraftData draftFile
    afterEdit = File.read(draftFile).split("\n")
    afterMeta = []
    afterDescription = []
    metaline = 0
    comment_part = false
    comment = []

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
          comment_part = false
        elsif line =~ /^@@@/
          comment_part = true
        elsif comment_part == true
          comment << line
        else
          afterMeta << line
        end
      else
        afterDescription << line
      end
    end

    res = {"issue" => {}}
    res["issue"]["description"] = afterDescription.join("\n")
    res["issue"]["notes"] = comment.join("\n") if ! comment.empty?

    duration = nil

    # TODO: ?????????????????????
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
        res["issue"]["project_id"] = parse_projectspec($1)
      when /^type:\s*(.*?)\s*$/i
        tmp = @metaCacheData["trackers"].find {|a| a["name"].downcase == $1.downcase}
        res["issue"]["tracker_id"] = tmp["id"] if tmp
      when /^priority:\s*(.*?)\s*$/i
        tmp = @metaCacheData["issue_priorities"].find {|a| a["name"].downcase == $1.downcase}
        res["issue"]["priority_id"] = tmp["id"] if tmp
      when /^estimatedtime:\s*(.*?)\s*$/i
        res["issue"]["estimated_hours"] = $1.to_i
      when /^startdate:\s*(.*?)\s*$/i
        res["issue"]["start_date"] = parse_date($1)
      when /^duedate:\s*(.*?)\s*$/i
        res["issue"]["due_date"] = parse_date($1)
      when /^parent:\s*(.*?)\s*$/i
        res["issue"]["parent_issue_id"] = $1 == "null" ? nil : $1.to_i
      when /^assigned:\s*(.*?)\s*$/i
        res["issue"]["assigned_to_id"] = parse_userspec($1)
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

  def saveDraftDuration draftFile, duration
    lines = File.read(draftFile).split("\n")
    metaline = 0
    comment_part = false
    lines.each_with_index do |line, i|
      if metaline == 0
        if line == "---"
          metaline = 1
        end
      elsif metaline == 1
        if line == "---"
          metaline = 2
          comment_part = false
        elsif line =~ /^@@@/
          comment_part = true
        end

        if comment_part == false and line =~ /^duration:\s*(.*?)(\+)?\s*$/i
          tmp = $1
          plus = $2
          # puts "--- [#{tmp}], [#{plus}], #{duration}"
          if tmp =~ /(\d+):(\d{2})/
            tmp = $1.to_i * 60 + $2.to_i
          else
            tmp = tmp.to_i
          end
          tmp += duration
          lines[i] = "Duration: #{tmp}+"
          break
        end
      end
    end
    lines << ""
    File.write(draftFile, lines.join("\n"))
  end

  # TODO: ??????????????????????????????????????????????????????????????????????????????
  def getDraftDuration draftFile, duration
    lines = File.read(draftFile).split("\n")
    metaline = 0
    lines.each_with_index do |line, i|
      if metaline == 0
        if line == "---"
          metaline = 1
        end
      elsif metaline == 1
        if line == "---"
          return 0
        elsif line =~ /^@@@/
          return 0
        end

        if line =~ /^duration:\s*(.*?)(\+)?\s*$/i
          tmp = $1
          plus = $2
          # puts "--- [#{tmp}], [#{plus}], #{duration}"
          return duration if tmp.nil?

          if tmp =~ /(\d+):(\d{2})/
            tmp2 = $1.to_i * 60 + $2.to_i
          elsif tmp == ""
            return duration
          else
            tmp2 = tmp.to_i
          end

          tmp2 += duration if plus == "+"
          return tmp2
        end
      end
    end
    return duration
  end

  # TODO: support adding comments
  def createTimeEntry id, duration
    if duration >= 3
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

  def parseWikiDraftData draftFile
    afterEdit = File.read(draftFile).split("\n")
    afterMeta = []
    afterDescription = []
    metaline = 0
    comment_part = false
    comment = []

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
          comment_part = false
        elsif line =~ /^@@@/
          comment_part = true
        elsif comment_part == true
          comment << line
        else
          afterMeta << line
        end
      else
        afterDescription << line
      end
    end

    res = {"wiki_page" => {}}

    afterMeta.each do |line|
      case line
      when /^wikiname:\s*(.*?)\s*$/i
        res["wiki_page"]["title"] = $1
      else
        raise "invalid metadata line #{line}"
      end
    end

    res["wiki_page"]["text"] = afterDescription.join("\n")
    res["wiki_page"]["comments"] = comment.join("\n") if ! comment.empty?
    return res
  end

  def ask_action
    if @options[:allyes] == true
      return "upload"
    else
      puts "Current server target is #{@options[:server]}"
      puts "You really upload this change? (y/Y: yes, n/N: no, s/S: save draft, e/E: edit again): "
      input = STDIN.gets.chomp
      if input[0] == 'n' or input[0] == 'N'
        return "cancel"
      elsif input[0] == 's' or input[0] == 'S'
        return "save"
      elsif input[0] == 'y' or input[0] == 'Y'
        return "upload"
      else
        return "editagain"
      end
    end
  end
end
