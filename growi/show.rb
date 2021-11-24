module GrowiCmdShow
  def show args
    updateWikiCache args

    args.each do |path|
      puts @cacheData[path]["page"]["revision"]["body"]
    end
  end
end
