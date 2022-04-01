# coding: utf-8

require 'time'

module GitLabCmdShow
  def show args
    id = args[0]
    pjid, iid, nid = id.split("-")

    case id_type(id)
    when "ticket"
      updateSingleNoteCache id

      issue = @cacheData[pjid][iid]
      note = @noteCacheData[pjid][iid] if nid
      draftData = draftIssueData("#{id}", issue, note)
      puts draftData
      puts "-" * 72

      return if @noteCacheData[pjid].nil? or @noteCacheData[pjid][iid].nil?

      notes = @noteCacheData[pjid][iid]
      notes.each do |note|
        if note["system"] == false
          tstamp = Time.parse(note["created_at"]).strftime("%Y-%m-%d %H:%M:%S")
          puts "#{pjid}-#{iid}-#{note["id"]} by #{note["author"]["username"]} at #{tstamp}"
          puts "#{note["body"]}"
        end
      end
    when "wiki"
      updateSingleWikiCache pjid
      baseurl = @metaCacheData["projects"][pjid]["web_url"]
      wikiIdx = iid[1..].to_i
      wiki = @wikiCacheData[pjid][wikiIdx]
      draftData = draftWikiData(wiki["title"], wiki["content"], {"Web URL" => "#{baseurl}/-/wikis/#{wiki["slug"]}"})
      puts draftData
    end
  end
end
