require_relative "../spec_helper"

describe "route_block_args plugin" do
  it "works with hooks when loaded last" do
    a = []
    app(:bare) do
      plugin :hooks
      before { a << 1 }
      after { a << 2 }
      plugin :route_block_args do
        [request, response]
      end
      route do |req, res|
        response.status = 401
        a << req.path << res.status
        "1"
      end
    end
    body.must_equal "1"
    a.must_equal [1, '/', 401, 2]
  end

  it "works with hooks when loaded first" do
    a = []
    app(:bare) do
      plugin :route_block_args do
        [request, response]
      end
      plugin :hooks
      before { a << 1 }
      after { a << 2 }
      route do |req, res|
        response.status = 401
        a << req.path << res.status
        "1"
      end
    end
    body.must_equal "1"
    a.must_equal [1, '/', 401, 2]
  end

  it "still supports a single route block argument" do
    app(:bare) do
      plugin :route_block_args do
        request
      end
      route { |r| "OK" }
    end

    status('/').must_equal(200)
  end

  it "supports many route block arguments" do
    app(:bare) do
      plugin :route_block_args do
        [request.params, request.env, response.headers, response.body]
      end
      route do |p, e, h, b|
        h['Foo'] = 'Bar'
        b << "#{p['a']}-#{e['B']}"
        "x"
      end
    end

    header('Foo', 'rack.input'=>StringIO.new).must_equal('Bar')
    body('rack.input'=>StringIO.new).must_equal('-')
    body('QUERY_STRING'=>'a=c', 'B'=>'D', 'rack.input'=>StringIO.new).must_equal('c-D')
  end

  it "works if given after the route block" do
    app(:bare) do
      route do |p, e, h, b|
        h['Foo'] = 'Bar'
        b << "#{p['a']}-#{e['B']}"
        "x"
      end
      plugin :route_block_args do
        [request.params, request.env, response.headers, response.body]
      end
    end

    header('Foo', 'rack.input'=>StringIO.new).must_equal('Bar')
    body('rack.input'=>StringIO.new).must_equal('-')
    body('QUERY_STRING'=>'a=c', 'B'=>'D', 'rack.input'=>StringIO.new).must_equal('c-D')
  end
end
