# coding: utf-8

module RedmineCmdWiki
  def wiki args
    OptionParser.new do |opts|
      opts.banner = "Usage:

  list all wiki pages:
    ticket wiki list

  list wiki pages in given projects:
    ticket wiki list <project>[...<project>]

  create wiki page:
    ticket wiki new <project> <wikiname>

  show wiki page:
    ticket wiki show <WikiID>

  show change history of wiki page:

    ticket wiki log <WikiID>

  edit wiki page:
    ticket wiki edit <WikiID>

  TODO: delete, rename

"
    end.order! args

    wikicmd = args.shift

    if wikicmd == "list"
      list_wiki_pages args
    elsif wikicmd == "show"
      show_wiki_page args
    elsif wikicmd == "log"
      show_wiki_page_log args
    elsif wikicmd == "new"
      create_wiki_page args
    elsif wikicmd == "edit"
      edit_wiki_page args
    elsif wikicmd == "debug"
      updateWikiCache args
    else
      raise "invalid subcommand: ticket wiki #{wikicmd}"
    end
  end

  def load_wiki_pages
    # TODO: need refactoring
    return if @loaded == true
    @metaCacheData["projects"].map {|pj| pj["id"].to_s}.each do |proj|
      collect_wiki_pages proj
    end
    @loaded = true
  end

  def list_wiki_pages args
    if args.size > 0
      projs = args.map {|a| parse_projectspec(a).to_i}
    else
      # all projects
      projs = @metaCacheData["projects"].map {|pj| pj["id"]}
    end

    updateWikiCache projs
    tmp = @wikiCacheData.select {|k,v| projs.include? v["project_id"]}
    tmp = tmp.sort_by {|_, v| v["updated_on"]}.map {|k, v| v}
    print_wiki_pages tmp
  end

  def create_wiki_page args
    raise "Usage: ticket wiki new <project> <wikiname>" if args.size != 2
    project = parse_projectspec args[0]
    wikiname = args[1]

    allyes = false
    draftFile = "#{@options["cachedir"]}/edit/newwiki.#{@serverconf["format"]}"
    prepareDraft draftFile, ""

    while true
      editDraft draftFile

      if allyes == true
        break
      else
        puts "You really upload this change? (y/Y: yes, n/N: no, s/S: save draft, e/E: edit again): "
        input = STDIN.gets.chomp
        if input[0] == 'n' or input[0] == 'N' or input[0] == 's' or input[0] == 'S'
          return
        elsif input[0] == 'y' or input[0] == 'Y'
          true
        else
          next
        end
      end

      uploadData = {"wiki_page" => {"text" => File.read(draftFile)}}
      response = uploadNewWiki project, wikiname, uploadData
      break
    end

    cleanupDraft draftFile
  end

  def show_wiki_page args
    raise "Usage: ticket wiki show <WikiID>" if args.size != 1
    wikiid = args[0]
    project = wikiid.split("-")[0]
    begin
      updateWikiCache [project]
      wikiname = @wikiCacheData[wikiid]["title"]
      uri = URI.encode("#{@baseurl}/projects/#{project}/wiki/#{wikiname}.json")
      params = {"key" => @serverconf["token"]}
      response = __get_response(uri, params)["wiki_page"]
      puts response["text"]
      @wikiCacheData[wikiid]["data"] = response
      wikiCacheFile = @options["cachedir"] + "/wikiCacheData"
      File.write(wikiCacheFile, @wikiCacheData.to_json)
    rescue
    end
  end

  def check_upload_draft draftFile
  end

  def edit_wiki_page args
    raise "Usage: ticket wiki edit <WikiID>" if args.size != 1
    wikiid = args[0]
    project = wikiid.split("-")[0]

    draftFile = "#{@options["cachedir"]}/edit/#{wikiid}.#{@serverconf["format"]}"
    begin
      updateWikiCache [project]
      wikiname = @wikiCacheData[wikiid]["title"]

      allyes = false
      uri = URI.encode("#{@baseurl}/projects/#{project}/wiki/#{wikiname}.json")
      params = {"key" => @serverconf["token"]}
      response = __get_response(uri, params)["wiki_page"]
      # puts ">>> prepareDraft #{draftFile}, [#{response["text"]}]"
      prepareDraft draftFile, draftWikiData(wikiname, response["text"].gsub(/\r\n?/, "\n"))
      check_upload_draft draftFile
    rescue
      puts "Failed to download wikipage from server. so only local cache can be edittable."
    end

    asyncUpdateMetaCache

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

  def uploadNewWiki proj, wikiname, draftData
    uri = URI.parse("#{@baseurl}/projects/#{proj}/wiki/#{wikiname}.json")
    @options[:logger].debug(draftData)
    response = put_issue uri, draftData

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "upload done"
    else
      raise response.value
    end
    return response
  end

  def collect_wiki_pages proj
    @wikiCacheData = {} if @wikiCacheData.nil?
    params = {"key" => @serverconf["token"]}
    issueAPI = "#{@baseurl}/projects/#{proj}/wiki/index.json"
    begin
      response = __get_response issueAPI, params
    rescue
      return
    end
    tmp = response["wiki_pages"].sort_by {|w| w["created_on"]}
    tmp.each_with_index do |w, i|
      if @wikiCacheData["#{proj}-#{i}"].nil?
        @wikiCacheData["#{proj}-#{i}"] = w
        w["project_id"] = proj.to_i
        w["wpid"] = "#{proj}-#{i}"
      else
        @wikiCacheData["#{proj}-#{i}"].merge! w
      end
    end
  end

  def get_wikiname id
    project = id.split("-")[0]
    collect_wiki_pages project
    return @wikiCacheData[id]["title"]
  end

  def print_wiki_pages wikis
    puts "WikiID\tVersion\tupdated_on\tWikiTitle"
    wikis.each do |wiki|
      puts "#{wiki["wpid"]}\t#{wiki["version"]}\t#{Time.parse(wiki["updated_on"]).getlocal.strftime("%Y/%m/%d %H:%M")}\t#{wiki["title"]}"
    end
  end

  def draftWikiData wikiname, text
    editdata = []
    editdata << "---"
    editdata << "WikiName: #{wikiname}"
    editdata << "@@@ lines from here to next '---' line is considered as note/comment"
    editdata << "---"
    editdata << text
    editdata << ""
    return editdata.join("\n")
  end

  def updateWikiCache proj=[]
    wikiCacheFile = @options["cachedir"] + "/wikiCacheData"
    if FileTest.exist? wikiCacheFile
      @wikiCacheData = JSON.parse(File.read(wikiCacheFile))
      proj.each do |pj|
        collect_wiki_pages pj
      end
    else
      FileUtils.mkdir_p(@options["cachedir"])
      load_wiki_pages
    end
    File.write(wikiCacheFile, @wikiCacheData.to_json)
  end

  def collectWikiPageHistory wikiids=[]
    wikiids.each do |wikiid|
      __collectWikiPageHistory wikiid
    end
    wikiCacheFile = @options["cachedir"] + "/wikiCacheData"
    File.write(wikiCacheFile, @wikiCacheData.to_json)
  end

  def __collectWikiPageHistory wikiid
    project = wikiid.split("-")[0]
    if @wikiCacheData[wikiid]["history"].nil?
      @wikiCacheData[wikiid]["history"] = {}
    end
    @wikiCacheData[wikiid]["version"].downto(1) do |i|
      next if @wikiCacheData[wikiid]["history"][i.to_s]
      getWikiPageOldVersion wikiid, project, i
    end
  end

  def getWikiPageOldVersion wikiid, project, version
    begin
      wikiname = @wikiCacheData[wikiid]["title"]
      uri = URI.encode("#{@baseurl}/projects/#{project}/wiki/#{wikiname}/#{version}.json")
      params = {"key" => @serverconf["token"]}
      response = __get_response(uri, params)["wiki_page"]
      if @wikiCacheData[wikiid]["history"].nil?
         @wikiCacheData[wikiid]["history"] = {}
      end
      @wikiCacheData[wikiid]["history"][version] = response
    rescue
    end
  end

  def show_wiki_page_log args
    raise "Usage: ticket wiki log <WikiID>" if args.size != 1
    wikiid = args[0]
    project = wikiid.split("-")[0]
    updateWikiCache [project]
    collectWikiPageHistory [wikiid]
    updateWikiCache [project]
    tmp = @wikiCacheData[wikiid]["history"]
    @wikiCacheData[wikiid]["version"].downto(2) do |i|
      puts "#" * 72
      puts "Version: #{i}"
      puts "Updated: #{tmp[i.to_s]["updated_on"]}"
      if tmp[i.to_s]["comments"]
        puts "Note: #{tmp[i.to_s]["comments"]}"
      end
      tmp3 = Diffy::Diff.new(tmp[(i-1).to_s]["text"], tmp[i.to_s]["text"], :context => 3, :include_diff_info => true).to_s.split("\n")
      tmp3.delete("\\ No newline at end of file")
      puts tmp3
    end
  end
end
