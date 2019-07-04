module Timeliness
  class Format
    include Helpers

    CompilationFailed = Class.new(StandardError)

    attr_reader :format_string, :regexp, :regexp_string, :token_count

    def initialize(format_string)
      @format_string = format_string
    end

    def compile!
      @token_count = 0
      found_tokens, token_order = [], []

      format = format_string.dup
      format.gsub!(/([\.\\])/, '\\\\\1') # escapes dots and backslashes

      # Substitute tokens with numbered placeholder
      Definitions.sorted_token_keys.each do |token|
        count = 0
        format.gsub!(token) do |_|
          token_regexp_str, arg_key = Definitions.format_tokens[token]
          token_index = found_tokens.size

          if arg_key
            raise CompilationFailed, "Token '#{token}' was found more than once in format '#{format_string}'. This has unexpected effects should be removed." if count > 0
            count += 1

            token_regexp_str = "(#{token_regexp_str})"
            @token_count += 1
          end
          found_tokens << [ token_regexp_str, arg_key ]

          "%<#{token_index}>"
        end
      end

      # Replace placeholders with token regexps
      format.gsub!(/%<(\d+)>/) do |placeholder|
        token_regexp_str, arg_key = found_tokens[$1.to_i]
        token_order << arg_key
        token_regexp_str
      end

      define_process_method(token_order.compact)
      @regexp_string = format
      @regexp = Regexp.new("^(#{format})$")
      self
    rescue => ex
      raise CompilationFailed, "The format '#{format_string}' failed to compile using regexp string #{format}. Error message: #{ex.inspect}"
    end

    # Redefined on compile
    def process(*args); end

    private

    def define_process_method(components)
      values = [nil] * 8
      components.each do |component|
        position, code = Definitions.format_components[component]
        values[position] = code || "#{component}.to_i" if position
      end
      instance_eval <<~DEF
      def process(#{components.join(',')})
        [#{values.map { |i| i || 'nil' }.join(',')}]
      end
      DEF
    end
  end
end
