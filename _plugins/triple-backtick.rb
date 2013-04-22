module Jekyll
  class MarkdownConverter
    alias :old_convert :convert
    def convert(content)
      content.gsub!(/(?:^|\n)```(\w*)\n(.*?)```\n/m) do |text|
        cls = $1.empty? ? "prettyprint" : "#{$1}"
        body = old_convert( $2 )
        body.sub! "<code>", "<code class=\"#{cls}\">"
        body
      end
      old_convert(content)
    end
  end
end
