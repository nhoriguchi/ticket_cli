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
    elsif wikicmd == "new"
      create_wiki_page args
    elsif wikicmd == "edit"
      edit_wiki_page args
    else
      raise "invalid subcommand: ticket wiki #{wikicmd}"
    end
  end

  def load_wiki_pages
    return if @loaded == true
    @wiki_pages = []
    @metaCacheData["projects"].map {|pj| pj["id"].to_s}.each do |proj|
      collect_wiki_pages proj
    end
    @loaded = true
  end

  def list_wiki_pages args
    if args.size > 0
      projs = args.map {|a| parse_project(a)}
    else
      # all projects
      projs = @metaCacheData["projects"].map {|pj| pj["id"].to_s}
    end

    @wiki_pages = []
    projs.each do |proj|
      collect_wiki_pages proj
    end
    @wiki_pages = @wiki_pages.sort_by {|w| w["updated_on"]}
    print_wiki_pages
    # pp @wiki_pages
  end

  def create_wiki_page args
    raise "Usage: ticket wiki new <project> <wikiname>" if args.size != 2
    project = parse_project args[0]
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

    @wiki_pages = []
    collect_wiki_pages project
    wikiname = @wiki_pages.find {|a| a["wpid"] == wikiid}["title"]

    uri = URI("#{@baseurl}/projects/#{project}/wiki/#{wikiname}.json")
    params = {"key" => @serverconf["token"]}
    response = __get_response(uri, params)["wiki_page"]
    puts response["text"]
  end

  def check_upload_draft draftFile
  end

  def edit_wiki_page args
    raise "Usage: ticket wiki edit <WikiID>" if args.size != 1
    wikiid = args[0]
    project = wikiid.split("-")[0]

    # TODO: need refactoring
    @wiki_pages = []
    collect_wiki_pages project
    wikiname = @wiki_pages.find {|a| a["wpid"] == wikiid}["title"]

    allyes = false
    uri = URI("#{@baseurl}/projects/#{project}/wiki/#{wikiname}.json")
    params = {"key" => @serverconf["token"]}
    draftFile = "#{@options["cachedir"]}/edit/#{wikiid}.#{@serverconf["format"]}"
    response = __get_response(uri, params)["wiki_page"]
    # puts ">>> prepareDraft #{draftFile}, [#{response["text"]}]"
    prepareDraft draftFile, response["text"]
    check_upload_draft draftFile

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

  def uploadNewWiki proj, wikiname, draftData
    uri = URI("#{@baseurl}/projects/#{proj}/wiki/#{wikiname}.json")
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

  def parse_project str
    if str =~ /^\d+$/
      return str
    else
      tmp = @metaCacheData["projects"].find {|a| a["name"].downcase == str.downcase}
      raise "invalid project #{str}" if tmp.nil?
      return tmp["id"].to_s
    end
  end

  def collect_wiki_pages proj
    params = {"key" => @serverconf["token"]}
    issueAPI = "#{@baseurl}/projects/#{proj}/wiki/index.json"
    response = __get_response issueAPI, params
    tmp = response["wiki_pages"].sort_by {|w| w["created_on"]}
    @wiki_pages += tmp.each_with_index {|w, i| w["wpid"] = "#{proj}-#{i}"}
  end

  def print_wiki_pages
    puts "WikiID\tVersion\tupdated_on\tWikiTitle"
    @wiki_pages.each do |wiki|
      puts "#{wiki["wpid"]}\t#{wiki["version"]}\t#{wiki["updated_on"]}\t#{wiki["title"]}"
    end
  end
end
