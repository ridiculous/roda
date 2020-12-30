# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The hash_routes plugin combines the O(1) dispatching speed of the static_routing plugin with
    # the flexibility of the multi_route plugin.  For any point in the routing tree,
    # it allows you dispatch to multiple routes where the next segment or the remaining path
    # is a static string.
    #
    # For a basic replacement of the multi_route plugin, you can replace class level
    # <tt>route('segment')</tt> calls with <tt>hash_branch('segment')</tt>:
    #
    #   class App < Roda
    #     plugin :hash_routes
    #
    #     hash_branch("a") do |r|
    #       # /a branch
    #     end
    #
    #     hash_branch("b") do |r|
    #       # /b branch
    #     end
    #
    #     route do |r|
    #       r.hash_branches
    #     end
    #   end
    #
    # With the above routing tree, the +r.hash_branches+ call in the main routing tree,
    # will dispatch requests for the +/a+ and +/b+ branches of the tree to the appropriate
    # routing blocks.
    #
    # In addition to supporting routing via the next segment, you can also support similar
    # routing for entire remaining path using the +hash_path+ class method:
    #
    #   class App < Roda
    #     plugin :hash_routes
    #
    #     hash_path("/a") do |r|
    #       # /a path
    #     end
    #
    #     hash_path("/a/b") do |r|
    #       # /a/b path 
    #     end
    #
    #     route do |r|
    #       r.hash_paths
    #     end
    #   end
    #
    # With the above routing tree, the +r.hash_paths+ call will dispatch requests for the +/a+ and
    # +/a/b+ request paths.
    #
    # You can combine the two approaches, and use +r.hash_routes+ to first try routing the
    # full path, and then try routing the next segment:
    #
    #   class App < Roda
    #     plugin :hash_routes
    #
    #     hash_branch("a") do |r|
    #       # /a branch
    #     end
    #
    #     hash_branch("b") do |r|
    #       # /b branch
    #     end
    #
    #     hash_path("/a") do |r|
    #       # /a path
    #     end
    #
    #     hash_path("/a/b") do |r|
    #       # /a/b path 
    #     end
    #
    #     route do |r|
    #       r.hash_routes
    #     end
    #   end
    #
    # With the above routing tree, requests for +/a+ and +/a/b+ will be routed to the appropriate
    # +hash_path+ block.  Other requests for the +/a+ branch, and all requests for the +/b+
    # branch will be routed to the appropriate +hash_branch+ block.
    #
    # Both +hash_branch+ and +hash_path+ support namespaces, which allows them to be used at
    # any level of the routing tree.  Here is an example that uses namespaces for sub-branches:
    #
    #   class App < Roda
    #     plugin :hash_routes
    #
    #     # Only one argument used, so the namespace defaults to '', and the argument
    #     # specifies the route name
    #     hash_branch("a") do |r|
    #       # uses '/a' as the namespace when looking up routes,
    #       # as that part of the path has been routed now
    #       r.hash_routes
    #     end
    #
    #     # Two arguments used, so first specifies the namespace and the second specifies
    #     # the route name
    #     hash_branch('', "b") do |r|
    #       # uses :b as the namespace when looking up routes, as that was explicitly specified
    #       r.hash_routes(:b)
    #     end
    #
    #     hash_path("/a", "/b") do |r|
    #       # /a/b path
    #     end
    #
    #     hash_path("/a", "/c") do |r|
    #       # /a/c path 
    #     end
    #
    #     hash_path(:b, "/b") do |r|
    #       # /b/b path
    #     end
    #
    #     hash_path(:b, "/c") do |r|
    #       # /b/c path 
    #     end
    #
    #     route do |r|
    #       # uses '' as the namespace, as no part of the path has been routed yet
    #       r.hash_branches
    #     end
    #   end
    #
    # With the above routing tree, requests for the +/a+ and +/b+ branches will be
    # dispatched to the appropriate +hash_branch+ block.  Those blocks will the dispatch
    # to the +hash_path+ blocks, with the +/a+ branch using the implicit namespace of
    # +/a+, and the +/b+ branch using the explicit namespace of +:b+.  In general, it
    # is best for performance to explicitly specify the namespace when calling
    # +r.hash_branches+, +r.hash_paths+, and +r.hash_routes+.
    #
    # Because specifying routes explicitly using the +hash_branch+ and +hash_path+
    # class methods can get repetitive, the hash_routes plugin offers a DSL for DRYing
    # the code up.  This DSL is used by calling the +hash_routes+ class method.  Below
    # is a translation of the previous example to using the +hash_routes+ DSL:
    #
    #   class App < Roda
    #     plugin :hash_routes
    #
    #     # No block argument is used, DSL evaluates block using instance_exec 
    #     hash_routes "" do
    #       # on method is used for routing to next segment,
    #       # for similarity to standard Roda
    #       on "a" do |r|
    #         r.hash_routes '/a'
    #       end
    #
    #       on "b" do |r|
    #         r.hash_routes(:b)
    #       end
    #     end
    #
    #     # Block argument is used, block is yielded DSL instance
    #     hash_routes "/a" do |hr|
    #       # is method is used for routing to the remaining path,
    #       # for similarity to standard Roda
    #       hr.is "b" do |r|
    #         # /a/b path
    #       end
    #
    #       hr.is "c" do |r|
    #         # /a/c path 
    #       end
    #     end
    #
    #     hash_routes :b do
    #       is "b" do |r|
    #         # /b/b path
    #       end
    #
    #       is "c" do |r|
    #         # /b/c path 
    #       end
    #     end
    #
    #     route do |r|
    #       # No change here, DSL only makes setup DRYer
    #       r.hash_branches
    #     end
    #   end
    #
    # The +hash_routes+ DSL also offers some additional features to handle additional
    # cases.  It supports verb methods, such as +get+ and +post+, which operate like
    # +is+, but are only called if the verb matches (and are not yielded the request).
    # It supports a +view+ method for routes that only render views, as well as a
    # +views+ method for setting up routes for multiple views in a single call, which
    # is a good replacement for the +multi_view+ plugin.
    # +is+, +view+, and the verb methods can use a value of +true+ for the empty
    # remaining path (as the empty string specifies the <tt>"/"</tt> remaining path).
    # It also supports a +dispatch_from+ method, allowing you to setup dispatching to
    # current group of routes from a higher-level namespace.
    # The +hash_routes+ class method will return the DSL instance, so you are not
    # limited to using it with a block.
    #
    # Here's the above example modified to use some of these features:
    #
    #   class App < Roda
    #     plugin :hash_routes
    #
    #     hash_routes "/a" do
    #       # Dispatch requests for the /a branch from the empty (default) routing
    #       # namespace to this namespace
    #       dispatch_from "a"
    #
    #       # Handle GET /a path, render "a" template, returning 404 for non-GET requests
    #       view true, "a"
    #
    #       # Handle /a/b path, returning 404 for non-GET requests
    #       get "b" do
    #         # GET /a/b path
    #       end
    #
    #       # Handle /a/c path, returning 404 for non-POST requests
    #       post "c" do
    #         # POST /a/c path 
    #       end
    #     end
    #
    #     bhr = hash_routes(:b)
    #
    #     # Dispatch requests for the /b branch from the empty routing to this namespace,
    #     # but first check routes in the :b_preauth namespace.  If there is no
    #     # matching route in the :b_preauth namespace, call the check_authenticated!
    #     # method before dispatching to any of the routes in this namespace
    #     bhr.dispatch_from "", "b" do |r|
    #       r.hash_routes :b_preauth
    #       check_authenticated!
    #     end
    #
    #     bhr.is true do |r|
    #       # /b path
    #     end
    #
    #     bhr.is "" do |r|
    #       # /b/ path 
    #     end
    #
    #     # GET /b/d path, render 'd2' template, returning 404 for non-GET requests
    #     bhr.views 'd', 'd2'
    #
    #     # GET /b/e path, render 'e' template, returning 404 for non-GET requests
    #     # GET /b/f path, render 'f' template, returning 404 for non-GET requests
    #     bhr.views %w'e f'
    #
    #     route do |r|
    #       r.hash_branches
    #     end
    #   end
    #
    # The +view+ and +views+ method depend on the render plugin being loaded, but this
    # plugin does not load the render plugin.  You must load the render plugin separately
    # if you want to use the +view+ and +views+ methods.
    #
    # Certain parts of the +hash_routes+ DSL support do not work with the
    # route_block_args plugin, as doing so would reduce performance.  These are:
    #
    # * dispatch_from
    # * view
    # * views
    # * all verb methods (get, post, etc.)
    module HashRoutes
      def self.configure(app)
        app.opts[:hash_branches] ||= {}
        app.opts[:hash_paths] ||= {}
        app.opts[:hash_routes_methods] ||= {}
      end

      # Internal class handling the internals of the +hash_routes+ class method blocks.
      class DSL
        def initialize(roda, namespace)
          @roda = roda
          @namespace = namespace
        end

        # Setup the given branch in the given namespace to dispatch to routes in this
        # namespace.  If a block is given, call the block with the request before
        # dispatching to routes in this namespace.
        def dispatch_from(namespace='', branch, &block)
          ns = @namespace
          if block
            meth_hash = @roda.opts[:hash_routes_methods]
            key = [:dispatch_from, namespace, branch].freeze
            meth = meth_hash[key] = @roda.define_roda_method(meth_hash[key] || "hash_routes_dispatch_from_#{namespace}_#{branch}", 1, &block)
            @roda.hash_branch(namespace, branch) do |r|
              send(meth, r)
              r.hash_routes(ns)
            end
          else
            @roda.hash_branch(namespace, branch) do |r|
              r.hash_routes(ns)
            end
          end
        end

        # Use the segment to setup a branch in the current namespace.
        def on(segment, &block)
          @roda.hash_branch(@namespace, segment, &block)
        end

        # Use the segment to setup a path in the current namespace.
        # If path is given as a string, it is prefixed with a slash.
        # If path is +true+, the empty string is used as the path.
        def is(path, &block)
          path = path == true ? "" : "/#{path}"
          @roda.hash_path(@namespace, path, &block)
        end

        # Use the segment to setup a path in the current namespace that
        # will render the view with the given name if the GET method is
        # used, and will return a 404 if another request method is used.
        # If path is given as a string, it is prefixed with a slash.
        # If path is +true+, the empty string is used as the path.
        def view(path, template)
          path = path == true ? "" : "/#{path}"
          @roda.hash_path(@namespace, path) do |r|
            r.get do
              view(template)
            end
          end
        end

        # For each template in the array of templates, setup a path in
        # the current namespace for the template using the same name
        # as the template.
        def views(templates)
          templates.each do |template|
            view(template, template)
          end
        end

        [:get, :post, :delete, :head, :options, :link, :patch, :put, :trace, :unlink].each do |meth|
          define_method(meth) do |path, &block|
            verb(meth, path, &block)
          end
        end

        private
        
        # Setup a path in the current namespace for the given request method verb.
        # Returns 404 for requests for the path with a different request method.
        def verb(verb, path, &block)
          path = path == true ? "" : "/#{path}"
          meth_hash = @roda.opts[:hash_routes_methods]
          key = [@namespace, path].freeze
          meth = meth_hash[key] = @roda.define_roda_method(meth_hash[key] || "hash_routes_#{@namespace}_#{path}", 0, &block)
          @roda.hash_path(@namespace, path) do |r|
            r.send(verb) do
              send(meth)
            end
          end
        end
      end

      module ClassMethods
        # Freeze the hash_routes metadata when freezing the app.
        def freeze
          opts[:hash_branches].freeze.each_value(&:freeze)
          opts[:hash_paths].freeze.each_value(&:freeze)
          opts[:hash_routes_methods].freeze
          super
        end

        # Duplicate hash_routes metadata in subclass.
        def inherited(subclass)
          super

          [:hash_branches, :hash_paths].each do |k|
            h = subclass.opts[k]
            opts[k].each do |namespace, routes|
              h[namespace] = routes.dup
            end
          end
        end

        # Invoke the DSL for configuring hash routes, see DSL for methods inside the
        # block.  If the block accepts an argument, yield the DSL instance.  If the
        # block does not accept an argument, instance_exec the block in the context
        # of the DSL instance.
        def hash_routes(namespace='', &block)
          dsl = DSL.new(self, namespace)
          if block
            if block.arity == 1
              yield dsl
            else
              dsl.instance_exec(&block)
            end
          end

          dsl
        end

        # Add branch handler for the given namespace and segment.
        def hash_branch(namespace='', segment, &block)
          segment = "/#{segment}"
          routes = opts[:hash_branches][namespace] ||= {}
          routes[segment] = define_roda_method(routes[segment] || "hash_branch_#{namespace}_#{segment}", 1, &convert_route_block(block))
        end

        # Add path handler for the given namespace and path. When the
        # r.hash_paths method is called, checks the matching namespace
        # for the full remaining path, and dispatch to that block if
        # there is one.
        def hash_path(namespace='', path, &block)
          routes = opts[:hash_paths][namespace] ||= {}
          routes[path] = define_roda_method(routes[path] || "hash_path_#{namespace}_#{path}", 1, &convert_route_block(block))
        end
      end

      module RequestMethods
        # Checks the matching hash_branch namespace for a branch matching the next
        # segment in the remaining path, and dispatch to that block if there is one.
        def hash_branches(namespace=matched_path)
          rp = @remaining_path

          return unless rp.getbyte(0) == 47 # "/"

          if routes = roda_class.opts[:hash_branches][namespace]
            if segment_end = rp.index('/', 1)
              if meth = routes[rp[0, segment_end]]
                @remaining_path = rp[segment_end, 100000000]
                always{scope.send(meth, self)}
              end
            elsif meth = routes[rp]
              @remaining_path = ''
              always{scope.send(meth, self)}
            end
          end
        end

        # Checks the matching hash_path namespace for a branch matching the 
        # remaining path, and dispatch to that block if there is one.
        def hash_paths(namespace=matched_path)
          if (routes = roda_class.opts[:hash_paths][namespace]) && (meth = routes[@remaining_path])
            @remaining_path = ''
            always{scope.send(meth, self)}
          end
        end

        # Check for matches in both the hash_path and hash_branch namespaces for
        # a matching remaining path or next segment in the remaining path, respectively.
        def hash_routes(namespace=matched_path)
          hash_paths(namespace)
          hash_branches(namespace)
        end
      end
    end

    register_plugin(:hash_routes, HashRoutes)
  end
end
