require_relative "spec_helper"

require 'tmpdir'

describe "plugins" do
  it "should be able to override class, instance, response, and request methods, and execute configure method" do
    c = Module.new do
      self::ClassMethods = Module.new do
        def fix(str)
          opts[:prefix] + str.strip
        end
      end
      self::InstanceMethods = Module.new do
        def fix(str)
          super("a" + str)
        end
      end
      self::RequestMethods = Module.new do
        def hello(&block)
          on self.class.hello, &block
        end
      end
      self::RequestClassMethods = Module.new do
        def hello(&block)
          'hello'
        end
      end
      self::ResponseMethods = Module.new do
        def foobar
          self.class.foobar
        end
      end
      self::ResponseClassMethods = Module.new do
        def foobar
          "Default   "
        end
      end

      def self.load_dependencies(mod, prefix)
        mod.send(:include, Module.new do
          def fix(str)
            self.class.fix(str)
          end
        end)
      end

      def self.configure(mod, prefix)
        mod.opts[:prefix] = prefix
      end
    end

    app(:bare) do
      plugin(c, "Foo ").must_be_nil

      route do |r|
        r.hello do
          fix(response.foobar)
        end
      end
    end

    body('/hello').must_equal 'Foo aDefault'
  end

  it "should support registering plugins and loading them by symbol" do
    Roda::RodaPlugins.register_plugin(:foo, Module.new{module self::InstanceMethods; def a; '1' end end})
    app(:foo) do
      a
    end

    body.must_equal '1'
  end

  it "should warn if attempting to load a plugin with arguments or a block" do
    Roda::RodaPlugins.register_plugin(:foo, Module.new)
    proc{app.plugin :foo, 1}.must_output(nil, /does not accept arguments or a block/)
    @app = nil
    proc{app.plugin(:foo){}}.must_output(nil, /does not accept arguments or a block/)
  end

  it "should raise error if attempting to load an invalid plugin" do
    proc{app(:banana)}.must_raise LoadError

    Dir.mktmpdir do |dir|
      begin
        $:.unshift(dir)
        Dir.mkdir(File.join(dir, 'roda'))
        Dir.mkdir(File.join(dir, 'roda', 'plugins'))
        File.write(File.join(dir, 'roda', 'plugins', 'banana.rb'), '')
        proc{app(:banana)}.must_raise Roda::RodaError

        c = Class.new(Roda)
        proc{c.plugin('banana')}.must_raise Roda::RodaError
      ensure
        $:.delete(dir)
      end
    end
  end
end
