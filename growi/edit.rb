require 'growi-client'

module GrowiCmdEdit
  def edit args
    updateWikiCache args

    args.each do |path|
      tmp = @cacheData[path]["page"]["revision"]["body"]
      prepareDraft draftPath(@cacheData[path]["_id"]), tmp
    end

    ids = args.map {|path| @cacheData[path]["_id"]}

    t1 = Time.now
    while true
      editDrafts ids
      diffDrafts ids
      action = ask_action
      case action
      when "upload"
        uploadDrafts args
        break
      when "cancel"
        puts "Moved draft file(s) to #{@options["cachedir"]}/deleted_drafts"
        cancelDrafts ids
        break
      when "save"
        saveDrafts ids, t1
        break
      end
    end
  end

  def uploadDrafts args
    args.each do |path|
      __uploadDrafts path
    end
  end

  def __uploadDrafts path
    id = @cacheData[path]["_id"]
    tmp = Diffy::Diff.new(File.read(draftOrigPath(id)), File.read(draftPath(id)), :context => 3).to_s.split("\n")
    tmp.delete("\\ No newline at end of file")
    if tmp.empty?
      puts "no change on draft file."
      return
    end

    basediff = ""
    # basediff = checkConflict path
    if not basediff.empty?
      open(draftPath(id), 'a') do |f|
        f.puts ""
        f.puts "### CONFLICT ### YOU NEED TO CONFLICET THE BELOW DIFF MANUALLY"
        f.puts basediff
      end
      puts "conflict detected (#{id}), edit it again."
      return
    end

    uploadData = parseGrowiPageData path, draftPath(id)
    @options[:logger].debug(uploadData)
    response = uploadWikiPage path, uploadData
    cleanupDraft draftPath(id)
  end

  def id_type str
    return ''
  end

  def parseGrowiPageData path, f
    return File.read(f)
  end

  def checkConflict path
    id = @cacheData[path]["_id"]
    draftFileOrig = draftOrigPath(id)
    conflictFile = draftConflictPath(id)
    prepareDraft conflictFile, getWikiData(path)

    tmp = Diffy::Diff.new(File.read(draftFileOrig), File.read(conflictFile), :context => 3).to_s.split("\n")
    tmp.delete("\\ No newline at end of file")
    FileUtils.mv(conflictFile, draftFileOrig)
    return tmp.join("\n")
  end

  def uploadWikiPage path, data
    id = @cacheData[path]["_id"]
    revisionId = @cacheData[path]["revision"]
    req = GApiRequestPagesUpdate.new(page_id: id, body: data, revision_id: revisionId, grant: 1)
    res = @gclient.request(req)
  end
end
