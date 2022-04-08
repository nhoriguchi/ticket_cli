# coding: utf-8

module GitLabCmdEdit
  def edit args
    args.each do |id|
      # id = args[0]
      pjid, iid, nid = id.split("-")

      case id_type id
      when "new"
        draftFile = "#{@options["cachedir"]}/edit/#{id}.md"
        draftData = draftIssueData("#{id}", {}, nil)
        prepareDraft draftFile, draftData
      when "ticket"
        updateSingleNoteCache id

        issue = @cacheData[pjid][iid]
        note = @noteCacheData[pjid][iid] if nid
        draftData = draftIssueData("#{id}", issue, note)
        draftFile = "#{@options["cachedir"]}/edit/#{id}.md"
        prepareDraft draftFile, draftData
      when "wiki"
        updateSingleWikiCache pjid
        wikiIdx = iid[1..].to_i
        # wiki = @wikiCacheData[pjid][wikiIdx]
        # wikiAPI = "#{@baseurl}/projects/#{pjid}/wikis/#{wiki["slug"]}"
        # wiki = __get_response wikiAPI, {}
        wiki = @wikiCacheData[pjid][wikiIdx]
        draftFile = "#{@options["cachedir"]}/edit/#{id}.md"
        prepareDraft draftFile, draftWikiData(wiki["title"], wiki["content"])
      end
    end

    t1 = Time.now
    while true
      editDrafts args
      diffDrafts args
      action = ask_action
      case action
      when "upload"
        uploadDrafts args, t1
        break
      when "cancel"
        puts "Moved draft file(s) to #{@options["cachedir"]}/deleted_drafts"
        cancelDrafts args
        break
      when "save"
        saveDrafts args, t1
        break
      end
    end
  end

  def id_type str
    if str =~ /^\d+$/
      return "new"
    elsif str =~ /^\d+-\d+/
      return "ticket"
    elsif str =~ /^\d+-w\d+/
      return "wiki"
    else
      return "ticket"
    end
  end

  def uploadDrafts ids, t1
    t2 = Time.now
    ids.each do |id|
      case id_type(id)
      when "wiki"
        __uploadWikiDraft id
      when "ticket"
        __uploadTicketDraft id, ((t2 - t1).to_i / 60)
      when "new"
        __uploadNewIssueDraft id
      end
    end
  end

  def __uploadWikiDraft id
    tmp = Diffy::Diff.new(File.read(draftOrigPath(id)), File.read(draftPath(id)), :context => 3).to_s.split("\n")
    tmp.delete("\\ No newline at end of file")
    if tmp.empty?
      puts "no change on draft file."
      return
    end

    # TODO: checkConflict id

    pjid, iid, nid = id.split("-")
    project = id.split("-")[0]
    uploadData = parseWikiDraft draftPath(id)
    pp uploadData
    wikiIdx = iid[1..].to_i
    wiki = @wikiCacheData[pjid][wikiIdx]
    response = uploadWiki pjid, wiki["slug"], uploadData
    cleanupDraft draftPath(id)
  end

  def __uploadTicketDraft id, elapsed
    uploadData, comment = parseDraft draftPath(id)
    uploadData["private_token"] = @serverconf["token"]
    tmp = Diffy::Diff.new(File.read(draftOrigPath(id)), File.read(draftPath(id)), :context => 3).to_s.split("\n")
    tmp.delete("\\ No newline at end of file")
    if tmp.empty?
      puts "no change on draft file."
      return
    end
    # apply_ticket_rules uploadData
    # 追記型ならそんなに conflict を気にしなくてもよいのではないか。
    uploadIssue id, uploadData

    if comment
      comment["private_token"] = @serverconf["token"]
      uploadComment id, comment
    end

    # # createTimeEntry (TODO: 複数チケットをオープンしている場合分割する?)
    # duration = getDraftDuration(draftPath(id), elapsed)
    # @options[:logger].debug("duration #{duration}, diff #{elapsed}")
    # createTimeEntry id, duration
    # puts "created time_entry (#{duration} min) to ID #{id}"

    # update succeeded so clean up draft files
    cleanupDraft draftPath(id)
  end

  def __uploadNewIssueDraft id
    uploadData, comment = parseDraft draftPath(id)
    uploadData["private_token"] = @serverconf["token"]
    uploadIssue id, uploadData
    cleanupDraft draftPath(id)
  end

  def uploadIssue id, draftData
    pjid, iid = id.split("-")
    if iid
      issueAPI = URI("#{@baseurl}/projects/#{pjid}/issues/#{iid}")
      response = put_issue issueAPI, draftData
    else
      issueAPI = URI("#{@baseurl}/projects/#{pjid}/issues")
      response = post_issue issueAPI, draftData
    end

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
  end

  def uploadComment id, comment
    pjid, iid, nid = id.split("-")
    if nid
      noteAPI = URI("#{@baseurl}/projects/#{pjid}/issues/#{iid}/notes/#{nid}")
      response = put_issue noteAPI, comment
    else
      noteAPI = URI("#{@baseurl}/projects/#{pjid}/issues/#{iid}/notes")
      response = post_issue noteAPI, comment
    end

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
  end

  def uploadWiki proj, wikiname, draftData
    uri = URI.parse("#{@baseurl}/projects/#{proj}/wikis/#{wikiname}")
    response = put_issue uri, draftData

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
    return response
  end

  def draftIssueData id, data, note
    pjid, iid, nid = id.split("-")
    editdata = []
    editdata << "---"
    editdata << "Subject: #{data["title"]}"
    editdata << "State: #{data["state"]}"
    editdata << "Type: #{data["type"]}"
    editdata << "Web URL: #{data["web_url"]}"
    if data["created_at"]
      created = Time.parse(data["created_at"]).strftime("%Y-%m-%d %H:%M:%S")
      editdata << "Created at #{created}"
    end
    if data["updated_at"]
      updated = Time.parse(data["updated_at"]).strftime("%Y-%m-%d %H:%M:%S")
      editdata << "Updated at #{updated}"
    end
    if data["time_stats"]
      editdata << "EstimatedTime: #{data["time_stats"]["time_estimate"]}"
      editdata << "SpentTime: #{data["time_stats"]["total_time_spent"]}"
    end
    editdata << "DueDate: #{data["due_date"]}"
    editdata << "Duration:"
    editdata << "@@@ lines from here to next '---' line is considered as note/comment"
    if note
      editdata << note["body"]
    end
    editdata << "---"
    if data["description"]
      editdata << data["description"].gsub(/\r\n?/, "\n")
    end
    editdata << ""
    return editdata.join("\n")
  end

  def parseDraft draftFile
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

    res = {}
    res["description"] = afterDescription.join("\n")

    afterMeta.each do |line|
      case line
      when /^subject:\s*(.*?)\s*$/i
        res["title"] = $1
      when /^progress:\s*(.*?)\s*$/i
        res["progress"] = $1.to_i
      when /^estimatedtime:\s*(.*?)\s*$/i
        # https://docs.gitlab.com/ee/api/issues.html#add-spent-time-for-an-issue
        res["time_estimate"] = $1.to_i
      when /^spenttime:\s*(.*?)\s*$/i
        res["total_time_spent"] = $1.to_i
      when /^duedate:\s*(.*?)\s*$/i
        res["due_date"] = $1 # parse_date($1)
      end
    end

    note = nil
    if not comment.empty?
      note = {"body" => comment.join("\n")}
    end

    return res, note
  end

  def draftWikiData title, data, meta={}
    editdata = []
    editdata << "---"
    editdata << "Subject: #{title}"
    meta.each do |k, v|
      editdata << "#{k}: #{v}"
    end
    editdata << "@@@ lines from here to next '---' line is considered as note/comment"
    editdata << "---"
    editdata << data
    editdata << ""
    return editdata.join("\n")
  end

  def parseWikiDraft draftFile
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

    res = {"format": "markdown"}
    res["content"] = afterDescription.join("\n")

    afterMeta.each do |line|
      case line
      when /^subject:\s*(.*?)\s*$/i
        res["title"] = $1
      end
    end

    return res
  end
end
