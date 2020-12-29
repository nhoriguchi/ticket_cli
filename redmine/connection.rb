# coding: utf-8

require 'openssl'

module RedmineConnection
  private

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
      response = Net::HTTP.get_response(uri)
    end

    raise "http request failed." if response.code != "200"
    return JSON.load(response.body)
  end

  def __get_response_all api, params
    res = __get_response api, params

    issues = res["issues"]

    total = res["total_count"]
    if total > params["limit"]
      1.upto(total/params["limit"]) do |i|
        puts "#{i * params["limit"]} to #{total - (i) * params["limit"]}"
        # offset=$[i*step]&limit=$[limit-i*step]
        tmpres = __get_response api, params.merge({"offset" => i * params["limit"], "limit" => total - i * params["limit"]})
        issues += tmpres["issues"]
      end
    end
    return issues
  end

  def put_issue uri, data
    if @options["baseport"].to_i == 443
      verify = OpenSSL::SSL::VERIFY_PEER
      verify = OpenSSL::SSL::VERIFY_NONE if @options[:insecure]

      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      :verify_mode => verify) do |http|
        request = Net::HTTP::Put.new(uri.to_s)
        request.set_content_type("application/json")
        request["X-Redmine-API-Key"] = @options["token"]
        request.body = data.to_json
        response = http.request request
      end
    else
      raise "no http connection supported"
    end
  end

  def post_time_entry uri, data
    if @options["baseport"].to_i == 443
      verify = OpenSSL::SSL::VERIFY_PEER
      verify = OpenSSL::SSL::VERIFY_NONE if @options[:insecure]

      Net::HTTP.start(uri.host, uri.port,
                      :use_ssl => uri.scheme == 'https',
                      :verify_mode => verify) do |http|
        request = Net::HTTP::Post.new(uri.to_s)
        request.set_content_type("application/json")
        request["X-Redmine-API-Key"] = @options["token"]
        request.body = data.to_json
        response = http.request request
      end
    else
      raise "no http connection supported"
    end
  end
end
