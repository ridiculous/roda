require_relative "../spec_helper"

describe "multi_public plugin" do 
  it "adds r.multi_public for serving static files from public folder" do
    app(:bare) do
      plugin :multi_public, :a => 'spec/views', :b => 'spec'

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    status("/about/_test.erb\0").must_equal 404
    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/static/views/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/foo/.././/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it "respects the application's :root option" do
    app(:bare) do
      opts[:root] = File.expand_path('../../', __FILE__)
      plugin :multi_public, :a => 'views', :b => '.'

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/static/views/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it "appends to directories if loaded a second time" do
    app(:bare) do
      plugin :multi_public, :a => 'spec/views'
      plugin :multi_public, :b => 'spec'

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/static/views/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/foo/.././/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it "support headers and default mime types per directory" do
    app(:bare) do
      plugin :multi_public,
        :a => ['spec/views', {'X-Foo' => 'bar'}, nil],
        :b => ['spec', nil, 'foo/bar']

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header('Content-Type', '/about/_test.erb').must_equal 'text/plain'
    header('X-Foo', '/about/_test.erb').must_equal 'bar'

    body('/static/views/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header('Content-Type', '/static/views/about/_test.erb').must_equal 'foo/bar'
    header('X-Foo', '/static/views/about/_test.erb').must_be_nil
  end


  it "loads the public plugin with the given options" do
    app(:bare) do
      plugin :multi_public, {}, :root=>'spec/views', :headers=>{'X-Foo' => 'bar'}, :default_mime=>'foo/bar'

      route do |r|
        r.public
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header('Content-Type', '/about/_test.erb').must_equal 'foo/bar'
    header('X-Foo', '/about/_test.erb').must_equal 'bar'
  end

  it "handles serving gzip files in gzip mode if client supports gzip" do
    app(:bare) do
      plugin :multi_public, {:a => 'spec/views', :b => 'spec'}, :gzip=>true

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header('Content-Encoding', '/about/_test.erb').must_be_nil

    body('/about.erb').must_equal File.read('spec/views/about.erb')
    header('Content-Encoding', '/about.erb').must_be_nil

    body('/about/_test.erb', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip').must_equal File.binread('spec/views/about/_test.erb.gz')
    h = req('/about/_test.erb', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip')[1]
    h['Content-Encoding'].must_equal 'gzip'
    h['Content-Type'].must_equal 'text/plain'

    body('/static/views/about/_test.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip').must_equal File.binread('spec/views/about/_test.css.gz')
    h = req('/static/views/about/_test.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip')[1]
    h['Content-Encoding'].must_equal 'gzip'
    h['Content-Type'].must_equal 'text/css'

    s, h, b = req('/static/views/about/_test.css', 'HTTP_IF_MODIFIED_SINCE'=>h["Last-Modified"], 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip')
    s.must_equal 304
    h['Content-Encoding'].must_be_nil
    h['Content-Type'].must_be_nil
    b.must_equal []
  end

  it "handles serving brotli files in brotli mode if client supports brotli and falls back gracefully" do
    app(:bare) do
      plugin :multi_public, {:a => 'spec/views', :b => 'spec'}, :gzip=>true, :brotli=>true

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end
    
    body('/about/_test2.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip, br').must_equal File.binread('spec/views/about/_test2.css.br')
    h = req('/about/_test2.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip, br')[1]
    h['Content-Encoding'].must_equal 'br'
    h['Content-Type'].must_equal 'text/css'

    body('/about/_test2.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip').must_equal File.binread('spec/views/about/_test2.css.gz')
    h = req('/about/_test2.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip')[1]
    h['Content-Encoding'].must_equal 'gzip'
    h['Content-Type'].must_equal 'text/css'

    body('/static/views/about/_test2.css').must_equal File.binread('spec/views/about/_test2.css')
    h = req('/static/views/about/_test2.css')[1]
    h['Content-Encoding'].must_be_nil
    h['Content-Type'].must_equal 'text/css'

    body('/static/views/about/_test.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip, br').must_equal File.binread('spec/views/about/_test.css.gz')
    h = req('/static/views/about/_test.css', 'HTTP_ACCEPT_ENCODING'=>'deflate, gzip, br')[1]
    h['Content-Encoding'].must_equal 'gzip'
    h['Content-Type'].must_equal 'text/css'
  end

  it "does not handle non-GET requests" do
    app(:bare) do
      plugin :multi_public, :a => 'spec/views'

      route do |r|
        r.multi_public(:a)
      end
    end

    status("/about/_test.erb", "REQUEST_METHOD"=>"POST").must_equal 404
  end
end

