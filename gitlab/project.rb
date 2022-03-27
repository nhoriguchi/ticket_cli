
module GitLabCmdProject
  def project args
    @config = {}

    @metaCacheData["projects"].each do |k, v|
      puts "#{k}\t#{v["path_with_namespace"]}"
    end
  end
end
