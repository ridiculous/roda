require_relative "../spec_helper"

require 'logger'

describe "common_logger plugin" do
  def cl_app(&block)
    app(:common_logger, &block)
    @logger = StringIO.new
    @app.plugin :common_logger, @logger
  end

  it 'logs requests to given logger/stream' do
    cl_app(&:path_info)

    body.must_equal '/'
    @logger.rewind
    @logger.read.must_match(/\A- - - \[\d\d\/[A-Z][a-z]{2}\/\d\d\d\d:\d\d:\d\d:\d\d [-+]\d\d\d\d\] "GET \/ " 200 1 0.\d\d\d\d\n\z/)

    @logger.rewind
    @logger.truncate(0)
    body('', 'HTTP_X_FORWARDED_FOR'=>'1.1.1.1', 'REMOTE_USER'=>'je', 'REQUEST_METHOD'=>'POST', 'QUERY_STRING'=>'', "HTTP_VERSION"=>'HTTP/1.1').must_equal ''
    @logger.rewind
    @logger.read.must_match(/\A1\.1\.1\.1 - je \[\d\d\/[A-Z][a-z]{2}\/\d\d\d\d:\d\d:\d\d:\d\d [-+]\d\d\d\d\] "POST  HTTP\/1.1" 200 - 0.\d\d\d\d\n\z/)

    @logger.rewind
    @logger.truncate(0)
    body('/b', 'REMOTE_ADDR'=>'1.1.1.2', 'QUERY_STRING'=>'foo=bar', "HTTP_VERSION"=>'HTTP/1.0').must_equal '/b'
    @logger.rewind
    @logger.read.must_match(/\A1\.1\.1\.2 - - \[\d\d\/[A-Z][a-z]{2}\/\d\d\d\d:\d\d:\d\d:\d\d [-+]\d\d\d\d\] "GET \/b\?foo=bar HTTP\/1.0" 200 2 0.\d\d\d\d\n\z/)

    @logger.rewind
    @logger.truncate(0)
    body('/b', 'REMOTE_ADDR'=>'1.1.1.2', 'QUERY_STRING'=>'foo=bar', "HTTP_VERSION"=>'HTTP/1.0', "SCRIPT_NAME"=>"/a").must_equal '/b'
    @logger.rewind
    @logger.read.must_match(/\A1\.1\.1\.2 - - \[\d\d\/[A-Z][a-z]{2}\/\d\d\d\d:\d\d:\d\d:\d\d [-+]\d\d\d\d\] "GET \/a\/b\?foo=bar HTTP\/1.0" 200 2 0.\d\d\d\d\n\z/)

    @app.plugin :common_logger, Logger.new(@logger)
    @logger.rewind
    @logger.truncate(0)
    body.must_equal '/'
    @logger.rewind
    @logger.read.must_match(/\A- - - \[\d\d\/[A-Z][a-z]{2}\/\d\d\d\d:\d\d:\d\d:\d\d [-+]\d\d\d\d\] "GET \/ " 200 1 0.\d\d\d\d\n\z/)
  end

  it 'skips timer information if not available' do
    cl_app do |r|
      @_request_timer = nil
      r.path_info
    end

    body.must_equal '/'
    @logger.rewind
    @logger.read.must_match(/\A- - - \[\d\d\/[A-Z][a-z]{2}\/\d\d\d\d:\d\d:\d\d:\d\d [-+]\d\d\d\d\] "GET \/ " 200 1 -\n\z/)
  end

  it 'skips length information if not available' do
    cl_app do |r|
      r.halt [500, {}, []]
    end

    body.must_equal ''
    @logger.rewind
    @logger.read.must_match(/\A- - - \[\d\d\/[A-Z][a-z]{2}\/\d\d\d\d:\d\d:\d\d:\d\d [-+]\d\d\d\d\] "GET \/ " 500 - 0.\d\d\d\d\n\z/)
  end

  it 'does not log if an error is raised' do
    cl_app do |r|
      raise "foo"
    end

    begin
      body
    rescue => e
    end
    e.must_be_instance_of(RuntimeError)
    e.message.must_equal 'foo'
  end

  it 'logs errors if used with error_handler' do
    cl_app do |r|
      raise "foo"
    end
    @app.plugin :error_handler do |_|
      "bad"
    end

    body.must_equal 'bad'
    @logger.rewind
    @logger.read.must_match(/\A- - - \[\d\d\/[A-Z][a-z]{2}\/\d\d\d\d:\d\d:\d\d:\d\d [-+]\d\d\d\d\] "GET \/ " 500 3 0.\d\d\d\d\n\z/)
  end
end
