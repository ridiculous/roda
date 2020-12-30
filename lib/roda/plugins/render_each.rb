# frozen-string-literal: true

require_relative 'render'

#
class Roda
  module RodaPlugins
    # The render_each plugin allows you to render a template for each
    # value in an enumerable, returning the concatention of all of the
    # template renderings.  For example:
    #
    #   render_each([1,2,3], :foo)
    #
    # will render the +foo+ template 3 times.  Each time the template
    # is rendered, the local variable +foo+ will contain the given
    # value (e.g. on the first rendering +foo+ is 1).
    #
    # You can pass additional render options via an options hash:
    #
    #   render_each([1,2,3], :foo, views: 'partials')
    #
    # One additional option supported by is +:local+, which sets the
    # local variable containing the current value to use.  So:
    #
    #   render_each([1,2,3], :foo, local: :bar)
    #
    # Will render the +foo+ template, but the local variable used inside
    # the template will be +bar+.  You can use <tt>local: nil</tt> to
    # not set a local variable inside the template. By default, the
    # local variable name is based on the template name, with any
    # directories and file extensions removed.
    module RenderEach
      # Load the render plugin before this plugin, since this plugin
      # calls the render method.
      def self.load_dependencies(app)
        app.plugin :render
      end

      ALLOWED_KEYS = [:locals, :local].freeze

      module InstanceMethods
        # For each value in enum, render the given template using the
        # given opts.  The template and options hash are passed to +render+.
        # Additional options supported:
        # :local :: The local variable to use for the current enum value
        #           inside the template.  An explicit +nil+ value does not
        #           set a local variable.  If not set, uses the template name.
        def render_each(enum, template, opts=(no_opts = true; optimized_template = _cached_render_each_template_method(template); OPTS))
          if optimized_template
            return _optimized_render_each(enum, optimized_template, render_each_default_local(template), {})
          elsif opts.has_key?(:local)
            as = opts[:local]
          else
            as = render_each_default_local(template)
            if no_opts && optimized_template.nil? && (optimized_template = _optimized_render_method_for_locals(template, (locals = {as=>nil})))
              return _optimized_render_each(enum, optimized_template, as, locals)
            end
          end

          if as
            opts = opts.dup
            if locals = opts[:locals]
              locals = opts[:locals] = Hash[locals]
            else
              locals = opts[:locals] = {}
            end
            locals[as] = nil

            if (opts.keys - ALLOWED_KEYS).empty? && (optimized_template = _optimized_render_method_for_locals(template, locals))
              return _optimized_render_each(enum, optimized_template, as, locals)
            end
          end

          enum.map do |v|
            locals[as] = v if as
            render_template(template, opts)
          end.join
        end
        
        private

        # The default local variable name to use for the template, if the :local option
        # is not used when calling render_each.
        def render_each_default_local(template)
          File.basename(template.to_s).sub(/\..+\z/, '').to_sym
        end

        if Render::COMPILED_METHOD_SUPPORT
          # If compiled method support is enabled in the render plugin, return the
          # method name to call to render the template.  Return false if not given
          # a string or symbol, or if compiled method support for this template has
          # been explicitly disabled.  Otherwise return nil.
          def _cached_render_each_template_method(template)
            case template
            when String, Symbol
              if (method_cache = render_opts[:template_method_cache])
                _cached_template_method_lookup(method_cache, [:_render_locals, template, [template.to_sym]])
              end
            else
              false
            end
          end

          # Use an optimized render for each value in the enum.
          def _optimized_render_each(enum, optimized_template, as, locals)
            enum.map do |v|
              locals[as] = v
              send(optimized_template, locals)
            end.join
          end
        else
          # :nocov:
          def _cached_render_each_template_method(template)
            nil
          end
          # :nocov:
        end
      end
    end

    register_plugin(:render_each, RenderEach)
  end
end
