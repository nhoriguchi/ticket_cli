
module GitHubCmdProject
  def project args
    @config = {}

    @metaCacheData["reposid"].each do |k, v|
      puts "#{k}\t#{v["full_name"]}\t#{v["updated_at"]}"
    end
  end
end
