require 'json'

module Connection
  def __get_response api, params
    uri = URI(api)
    uri.query = URI.encode_www_form(params)

    response = nil
    if @options["baseport"].to_i == 443
      require 'openssl'
      verify = OpenSSL::SSL::VERIFY_PEER
      verify = OpenSSL::SSL::VERIFY_NONE if @options[:insecure]

      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      :verify_mode => verify) do |http|
        request = Net::HTTP::Get.new uri
        response = http.request request
      end
    else # for http connection
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri.to_s)
        response = http.request request
      end
    end

    raise "http request failed." if response.code != "200"
    return JSON.load(response.body)
  end
end
