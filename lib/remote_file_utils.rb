
require 'uri'
require 'fileutils'

module RemoteFileUtils

  # Fetch a single URL to a local file destination
  # Supports http(s) and s3 using wget and aws cli
  def download(source_url, localfile)
    FileUtils.mkdir_p(File.dirname(localfile))

    case source_url.scheme
    when "s3"
      cmd = "aws s3 cp #{source_url} #{localfile}"
    else
      cmd = "wget -nv -O'#{localfile}' '#{source_url}'"
    end

    err = `#{cmd} </dev/null 2>&1`
    if $? != 0
      raise "error during #{cmd} was: #{err}"
    end
    return "run >>> #{cmd} >>> #{err}"
  end
  module_function :download

end
