# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The multi_public plugin adds an +r.multi_public+ method that accepts an argument specifying
    # a directory from which to serve static files.  It is similar to the public plugin, but
    # allows for multiple separate directories.
    #
    # Here's an example of using the multi_public plugin to serve 3 different types of files
    # from 3 different directories:
    #
    #   plugin :multi_public,
    #     img:  'static/images',
    #     font: 'assets/fonts',
    #     form: 'static/forms/pdfs'
    #
    #   r.route do
    #     r.on "images" do
    #       r.multi_public(:img)
    #     end
    #
    #     r.on "fonts" do
    #       r.multi_public(:font)
    #     end
    #
    #     r.on "forms" do
    #       r.multi_public(:form)
    #     end
    #   end
    #
    # It is possible to simplify the routing tree for this using string keys and an array
    # matcher:
    # 
    #   plugin :multi_public,
    #     'images' => 'static/images',
    #     'fonts'  => 'assets/fonts',
    #     'forms'  => 'static/forms/pdfs'
    #
    #   r.route do
    #     r.on %w"images fonts forms" do |dir|
    #       r.multi_public(dir)
    #     end
    #   end
    #
    # You can provide custom headers and default mime type for each directory using an array
    # of three elements as the value, with the first element being the path, the second
    # being the custom headers, and the third being the default mime type:
    #
    #   plugin :multi_public,
    #     'images' => ['static/images', {'Cache-Control'=>'max-age=86400'}, nil],
    #     'fonts'  => ['assets/fonts', {'Cache-Control'=>'max-age=31536000'}, 'font/ttf'],
    #     'forms'  => ['static/forms/pdfs', nil, 'application/pdf']
    #
    #   r.route do
    #     r.on %w"images fonts forms" do |dir|
    #       r.multi_public(dir)
    #     end
    #   end
    module MultiPublic
      def self.load_dependencies(app, _, opts=OPTS)
        app.plugin(:public, opts)
      end

      # Use the given directories to setup servers.  Any opts are passed to the public plugin.
      def self.configure(app, directories, _=OPTS)
        roots = app.opts[:multi_public_servers] = (app.opts[:multi_public_servers] || {}).dup
        directories.each do |key, path|
          path, headers, mime = path
          roots[key] = ::Rack::File.new(app.expand_path(path), headers||{}, mime||'text/plain')
        end
        roots.freeze
      end

      module RequestMethods
        # Serve files from the directory corresponding to the given key if the file exists and
        # this is a GET request.
        def multi_public(key)
          public_serve_with(roda_class.opts[:multi_public_servers].fetch(key))
        end
      end
    end

    register_plugin(:multi_public, MultiPublic)
  end
end

