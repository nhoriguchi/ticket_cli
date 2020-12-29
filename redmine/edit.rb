# coding: utf-8

module RedmineCmdEdit
  def edit id
    raise "issue #{id} not found" if @cacheData[id].nil?
    a = updateCacheIssue id
    @cacheData[id] = a["issues"][0]
    tmp = draftData id

    editDir = "#{@config["cacheDir"]}/edit"
    FileUtils.mkdir_p(editDir)
    draftFile = "#{editDir}/#{id}.md"
    draftFileOrig = "#{editDir}/.#{id}.md"
    File.write(draftFile, tmp.join("\n"))

    # TODO: update metadata cache asynchronously here
    # TODO: calculate duration of editing
    # TODO: ask yes/no or progress update

    system "cp #{draftFile} #{draftFileOrig} ; #{ENV["EDITOR"]} #{draftFile}"
    ret = system("diff #{draftFile} #{draftFileOrig} > /dev/null")
    if ret == true
      puts "no change on draft file."
      return
    end

    updateData = parseDraftData draftFile

    uri = URI("#{@baseurl}/issues/#{id}.json")
    response = nil
    if @config["baseport"].to_i == 443
      require 'openssl'
      verify = OpenSSL::SSL::VERIFY_PEER
      verify = OpenSSL::SSL::VERIFY_NONE if ENV['INSECURE']

      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      :verify_mode => verify) do |http|
        request = Net::HTTP::Put.new(uri.to_s)
        request.set_content_type("application/json")
        request["X-Redmine-API-Key"] = @config["token"]
        request.body = updateData.to_json
        response = http.request request
      end
    else # for http connection
      raise "no http connection"
      response = Net::HTTP.get_response(uri)
    end

    case response
    when Net::HTTPSuccess, Net::HTTPRedirection
      puts "OK"
    else
      response.value
    end

    @cacheData = updateCache
  end
end
