require_relative "../spec_helper"

begin
  require 'tilt'
  require 'tilt/string'
  require 'tilt/rdoc'
  require_relative '../../lib/roda/plugins/render'
rescue LoadError
  warn "tilt not installed, skipping render_each plugin test"  
else
describe "render_each plugin" do 
  [true, false].each do |cache|
    it "calls render with each argument, returning joined string with all results in cache: #{cache} mode" do
      app(:bare) do
        plugin :render, :views=>'spec/views', :engine=>'str', :cache=>cache
        plugin :render_each

        o = Object.new
        def o.to_s; 'each' end

        route do |r|
          r.root do
            render_each([1,2,3], :each)
          end

          r.is 'a' do
            render_each([1,2,3], :each, :local=>:foo, :bar=>4)
          end

          r.is 'b' do
            render_each([1,2,3], :each, :local=>nil)
          end

          r.is 'c' do
            render_each([1,2,3], :each, :locals=>{:foo=>4})
          end

          r.is 'd' do
            render_each([1,2,3], {:template=>:each}, :local=>:each)
          end

          r.is 'e' do
            render_each([1,2,3], o)
          end

          r.is 'f' do
            render_each([1,2,3], "views/each", :views=>'spec')
          end

          r.is 'g' do
            render_each([1,2,3], "each.foo")
          end
        end
      end

      2.times do
        3.times do
          body.must_equal "r-1-\nr-2-\nr-3-\n"
          body("/a").must_equal "r--1\nr--2\nr--3\n"
          body("/b").must_equal "r--\nr--\nr--\n"
          body("/c").must_equal "r-1-4\nr-2-4\nr-3-4\n"
          body("/d").must_equal "r-1-\nr-2-\nr-3-\n"
          body("/e").must_equal "r-1-\nr-2-\nr-3-\n"
          body("/f").must_equal "r-1-\nr-2-\nr-3-\n"
          body("/g").must_equal "r-1-\nr-2-\nr-3-\n"
        end
        app.opts[:render] = app.opts[:render].dup
        app.opts[:render].delete(:template_method_cache)
      end
    end

    it "bases local name on basename of template in cache: #{cache} mode" do
      app(:bare) do
        plugin :render, :views=>'spec', :engine=>'str', :cache=>cache
        plugin :render_each

        route do |r|
          r.root do
            render_each([1,2,3], "views/each")
          end
        end
      end

      3.times do
        body.must_equal "r-1-\nr-2-\nr-3-\n"
      end
    end

    if Roda::RodaPlugins::Render::COMPILED_METHOD_SUPPORT
      it "calls render with each argument, handling template engines that don't support compilation in cache: #{cache} mode" do
        app(:bare) do
          plugin :render, :views=>'spec/views', :engine=>'rdoc', :cache=>cache
          plugin :render_each

          route do |r|
            r.root do
              render_each([1], :a)
            end
            r.is 'a' do
              render_each([1], :a, :local=>:b)
            end
          end
        end

        3.times do
          body.strip.must_equal "<p># a # * b</p>"
          body('/a').strip.must_equal "<p># a # * b</p>"
        end
      end
    end
  end
end
end
