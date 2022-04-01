# coding: utf-8

module GitHubCmdEdit
  def edit args
    projname = args.shift
    pjid = @metaCacheData["reposname"][projname]
    id = args[0]
    iid, nid = id.split("-")

    updateSingleMetaCache projname
    updateSingleCache projname

    # new issue
    if iid.nil?
      raise "issue creation not supported yet."
      draftFile = "#{@options["cachedir"]}/edit/#{id}.md"
      draftData = draftIssueData("#{id}", {}, nil)
      prepareDraft draftFile, draftData
    else
      updateSingleNoteCache pjid, iid

      issue = @cacheData[pjid][iid]
      if nid
        note = @noteCacheData[pjid][iid].find do |ns|
          ns["id"] = nid
        end
      end

      draftFile = "#{@options["cachedir"]}/edit/#{id}.md"
      draftData = draftIssueData("#{id}", issue, note)
      prepareDraft draftFile, draftData
    end

    t1 = Time.now
    while true
      editDrafts args
      diffDrafts args
      action = ask_action
      case action
      when "upload"
        uploadDrafts projname, args, t1
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
    if str =~ /^\d+-\d+/
      return "ticket"
    elsif str =~ /^\d+$/
      return "ticket"
    elsif str =~ /^\d+-w\d+$/
      return "wiki"
    else
      return "new"
    end
  end

  def uploadDrafts projname, ids, t1
    t2 = Time.now
    ids.each do |id|
      if id_type(id) == "wiki"
        __uploadWikiDraft id
      elsif id_type(id) == "ticket"
        __uploadTicketDraft projname, id, ((t2 - t1).to_i / 60)
      end
    end
  end

  def __uploadTicketDraft projname, id, elapsed
    # title, uploadData, comment = parseDraft draftPath(id)
    title, description, type, comment = parseDraft draftPath(id)

    tmp = Diffy::Diff.new(File.read(draftOrigPath(id)), File.read(draftPath(id)), :context => 3).to_s.split("\n")
    tmp.delete("\\ No newline at end of file")
    if tmp.empty?
      puts "no change on draft file."
      return
    end

    iid, nid = id.split("-")

    data = {}
    data["title"] = title
    data["type"] = type
    data["body"] = description

    uploadIssue projname, iid, data

    if comment
      if nid # update existing comment
        updateComment projname, iid, nid, {"body" => comment}
      else
        uploadComment projname, iid, {"body" => comment}
      end
    end

    # update succeeded so clean up draft files
    cleanupDraft draftPath(id)
  end

  def uploadIssue projname, iid, draftData
    issueAPI = URI("#{@baseurl}/repos/#{projname}/issues/#{iid}")
    response = post_issue issueAPI, draftData

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
  end

  def updateComment projname, iid, nid, comment
    noteAPI = URI("#{@baseurl}/repos/#{projname}/issues/comments/#{nid}")
    response = patch_issue_comment noteAPI, comment

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
  end

  def uploadComment projname, iid, comment
    noteAPI = URI("#{@baseurl}/repos/#{projname}/issues/#{iid}/comments")
    response = post_issue noteAPI, comment

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
  end

  def draftIssueData id, data, note
    pjid, iid, nid = id.split("-")
    editdata = []
    editdata << "---"
    editdata << "Subject: #{data["title"]}"
    editdata << "Type: #{data["labels"].join(",")}"
    editdata << "@@@ lines from here to next '---' line is considered as note/comment"
    if note
      editdata << note["body"]
    end
    editdata << "---"
    if data["body"]
      editdata << data["body"]
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

    description = afterDescription.join("\n")
    title = nil
    type = nil
    note = nil    

    afterMeta.each do |line|
      case line
      when /^subject:\s*(.*?)\s*$/i
        title = $1
      when /^type:\s*(.*+)\s*$/i
        type = $1.join(",") if not $1.empty?
      end
    end

    if not comment.empty?
      note = comment.join("\n")
    end

    return title, description, type, note
  end
end
