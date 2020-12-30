# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The match_hook plugin adds hooks that are called upon a successful match
    # by any of the matchers.
    #
    #   plugin :match_hook
    #
    #   match_hook do
    #     logger.debug("#{request.matched_path} matched. #{request.remaining_path} remaining.")
    #   end
    module MatchHook
      def self.configure(app)
        app.opts[:match_hooks] ||= []
      end

      module ClassMethods
        # Freeze the array of hook methods when freezing the app
        def freeze
          opts[:match_hooks].freeze
          super
        end

        # Add a match hook.
        def match_hook(&block)
          opts[:match_hooks] << define_roda_method("match_hook", 0, &block)

          if opts[:match_hooks].length == 1
            class_eval("alias _match_hook #{opts[:match_hooks].first}", __FILE__, __LINE__)
          else
            class_eval("def _match_hook; #{opts[:match_hooks].join(';')} end", __FILE__, __LINE__)
          end

          public :_match_hook

          nil
        end
      end

      module InstanceMethods
        # Default empty method if no match hooks are defined.
        def _match_hook
        end
      end

      module RequestMethods
        private

        # Call the match hook if yielding to the block before yielding to the block.
        def if_match(_)
          super do |*a|
            scope._match_hook
            yield(*a)
          end
        end

        # Call the match hook before yielding to the block
        def always
          scope._match_hook
          super
        end
      end
    end

    register_plugin :match_hook, MatchHook
  end
end
