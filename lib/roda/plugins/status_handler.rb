# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The status_handler plugin adds a +status_handler+ method which sets a
    # block that is called whenever a response with the relevant response code
    # with an empty body would be returned.
    #
    # This plugin does not support providing the blocks with the plugin call;
    # you must provide them to status_handler calls afterwards:
    #
    #   plugin :status_handler
    #
    #   status_handler(403) do
    #     "You are forbidden from seeing that!"
    #   end
    #   status_handler(404) do
    #     "Where did it go?"
    #   end
    #
    # Before a block is called, any existing headers on the response will be
    # cleared.  So if you want to be sure the headers are set even in your block,
    # you need to reset them in the block.
    module StatusHandler
      def self.configure(app)
        app.opts[:status_handler] ||= {}
      end

      module ClassMethods
        # Install the given block as a status handler for the given HTTP response code.
        def status_handler(code, &block)
          # For backwards compatibility, pass request argument if block accepts argument
          arity = block.arity == 0 ? 0 : 1
          opts[:status_handler][code] = [define_roda_method(:"_roda_status_handler_#{code}", arity, &block), arity]
        end

        # Freeze the hash of status handlers so that there can be no thread safety issues at runtime.
        def freeze
          opts[:status_handler].freeze
          super
        end
      end

      module InstanceMethods
        private

        # If routing returns a response we have a handler for, call that handler.
        def _roda_after_20__status_handler(result)
          if result && (meth, arity = opts[:status_handler][result[0]]; meth) && (v = result[2]).is_a?(Array) && v.empty?
            res = @_response
            res.headers.clear
            res.status = result[0]
            result.replace(_roda_handle_route{arity == 1 ? send(meth, @_request) : send(meth)})
          end
        end
      end
    end

    register_plugin(:status_handler, StatusHandler)
  end
end
