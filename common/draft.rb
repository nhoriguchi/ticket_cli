module Common
  def prepareDraft path, data
    return if File.exist? path
    dir = File.dirname path
    FileUtils.mkdir_p(dir)
    draftFile = path
    draftFileOrig = path + ".orig"
    File.write(draftFile, data)
    File.write(draftFileOrig, data)
  end

  def editDraft path
    draftFile = path
    draftFileOrig = path + ".orig"
    draftFileBackup = path + ".backup"
    system "#{ENV["EDITOR"]} #{draftFile}"
    FileUtils.cp draftFile, draftFileBackup
    ret = system("diff #{draftFile} #{draftFileOrig} > /dev/null")
    if ret == true
      puts "no change on draft file."
      return false
    end
    return true
  end

  def cleanupDraft path
    File.delete(path)
    File.delete(path + ".orig")
    File.delete(path + ".backup")
  end
end
