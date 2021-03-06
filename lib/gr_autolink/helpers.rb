# -*- coding: utf-8 -*-
module GrAutolink
  require 'active_support/core_ext/object/blank'
  require 'active_support/core_ext/array/extract_options'
  require 'active_support/core_ext/hash/reverse_merge'
  require 'active_support/core_ext/hash/keys'

  module ::ActionView
    module Helpers # :nodoc:
      module TextHelper
        # Turns all URLs and e-mail addresses into clickable links. The <tt>:link</tt> option
        # will limit what should be linked. You can add HTML attributes to the links using
        # <tt>:html</tt>. Possible values for <tt>:link</tt> are <tt>:all</tt> (default),
        # <tt>:email_addresses</tt>, and <tt>:urls</tt>. If a block is given, each URL and
        # e-mail address is yielded and the result is used as the link text. By default the
        # text given is sanitized, you can override this behaviour setting the
        # <tt>:sanitize</tt> option to false, or you can add options to the sanitization of
        # the text using the <tt>:sanitize_options</tt> option hash.
        # An optional flag <tt>:max_link_length</tt> can be passed to let the function truncate
        # the url text to the specified amount of characters
        #
        # ==== Examples
        #   auto_link("Go to http://www.rubyonrails.org and say hello to david@loudthinking.com")
        #   # => "Go to <a href=\"http://www.rubyonrails.org\">http://www.rubyonrails.org</a> and
        #   #     say hello to <a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>"
        #
        #   auto_link("Visit http://www.loudthinking.com/ or e-mail david@loudthinking.com", :link => :urls)
        #   # => "Visit <a href=\"http://www.loudthinking.com/\">http://www.loudthinking.com/</a>
        #   #     or e-mail david@loudthinking.com"
        #
        #   auto_link("Visit http://www.loudthinking.com/ or e-mail david@loudthinking.com", :link => :email_addresses)
        #   # => "Visit http://www.loudthinking.com/ or e-mail <a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>"
        #
        #   post_body = "Welcome to my new blog at http://www.myblog.com/.  Please e-mail me at me@email.com."
        #   auto_link(post_body, :html => { :target => '_blank' }) do |text|
        #     truncate(text, :length => 15)
        #   end
        #   # => "Welcome to my new blog at <a href=\"http://www.myblog.com/\" target=\"_blank\">http://www.m...</a>.
        #         Please e-mail me at <a href=\"mailto:me@email.com\">me@email.com</a>."
        #
        #   auto_link("Visit http://www.verylonglink.com/p/r/t/y/u/i/o/p/a.html", :max_link_length=>20)
        #   # => "Visit <a href=\"http://www.verylonglink.com/p/r/t/y/u/i/o/p/a.html\">http://www.verylo...</a>"
        #
        # You can still use <tt>auto_link</tt> with the old API that accepts the
        # +link+ as its optional second parameter and the +html_options+ hash
        # as its optional third parameter:
        #   post_body = "Welcome to my new blog at http://www.myblog.com/. Please e-mail me at me@email.com."
        #   auto_link(post_body, :urls)
        #   # => "Welcome to my new blog at <a href=\"http://www.myblog.com/\">http://www.myblog.com</a>.
        #         Please e-mail me at me@email.com."
        #
        #   auto_link(post_body, :all, :target => "_blank")
        #   # => "Welcome to my new blog at <a href=\"http://www.myblog.com/\" target=\"_blank\">http://www.myblog.com</a>.
        #         Please e-mail me at <a href=\"mailto:me@email.com\">me@email.com</a>."
        def auto_link(text, *args, &block)#link = :all, html = {}, &block)
          return ''.html_safe if text.blank?

          input_html_safe = text.html_safe?

          options = args.size == 2 ? {} : args.extract_options! # this is necessary because the old auto_link API has a Hash as its last parameter
          unless args.empty?
            options[:link] = args[0] || :all
            options[:html] = args[1] || {}
          end
          options.reverse_merge!(:link => :all, :html => {})
          sanitize = (options[:sanitize] != false)
          sanitize_options = options[:sanitize_options] || {}
          text = conditional_sanitize(text, sanitize, sanitize_options).to_str

          autolinked_text =
            case options[:link].to_sym
            when :all
              conditional_html_safe(auto_link_email_addresses(auto_link_urls(text, options[:html], options, &block), options[:html], &block), sanitize)
            when :email_addresses
              conditional_html_safe(auto_link_email_addresses(text, options[:html], &block), sanitize)
            when :urls
              conditional_html_safe(auto_link_urls(text, options[:html], options, &block), sanitize)
            end

          # regardless of sanitizing, make sure output is safe if input was safe
          autolinked_text = input_html_safe ? autolinked_text.html_safe : autolinked_text
          autolinked_text
        end

        private
          WORD_PATTERN = RUBY_VERSION < '1.9' ? '\w' : '\p{Word}'

          PROTOCOLS = %w{ed2k ftp http https irc mailto news gopher nntp telnet
                         webcal xmpp callto feed svn urn aim rsync tag ssh sftp
                         rtsp afs file z39.50r chrome}.map{|p| Regexp.escape p}.join('|')

          AUTO_LINK_RE = %r{
              (?: ((?:view\-source\:)?(?:#{PROTOCOLS}):)// | www\. | [a-zA-Z0-9.]+[a-zA-Z0-9]\.[a-zA-Z0-9]{2,}\/)
              [^\s<>\u00A0]+
            }ix

          # regexps for determining context, used high-volume
          AUTO_LINK_CRE = [/<[^>]+$/, /^[^>]*>/, /<a\b.*?>/i, /<\/a>/i]

          AUTO_EMAIL_LOCAL_RE = /[\w.!#\$%&'*\/=?^`{|}~+-]/
          AUTO_EMAIL_RE = /[\w.!#\$%+-]\.?#{AUTO_EMAIL_LOCAL_RE}*@[\w-]+(?:\.[\w-]+)+/

          BRACKETS = { ']' => '[', ')' => '(', '}' => '{' }

          # Turns all urls into clickable links.  If a block is given, each url
          # is yielded and the result is used as the link text.
          def auto_link_urls(text, html_options = {}, options = {})
            link_attributes = html_options.stringify_keys
            text.gsub(AUTO_LINK_RE) do
              scheme, href = $1, $&
              punctuation = []
              if auto_linked?($`, $')
                # do not change string; URL is already linked
                href
              else
                # don't include trailing punctuation character as part of the URL
                while href.sub!(/[^#{WORD_PATTERN}\/-]$/, '')
                  punctuation.push $&
                  if opening = BRACKETS[punctuation.last] and href.scan(opening).size > href.scan(punctuation.last).size
                    href << punctuation.pop
                    break
                  end
                end

                link_text = if block_given?
                              yield(href)
                            else
                              text.html_safe? ? href : escape(href)
                            end
                href = 'http://' + href unless scheme

                unless options[:sanitize] == false
                  link_text = sanitize(link_text)
                  href      = sanitize(href)
                end

                unless text.html_safe?
                  href = escape(href)
                end

                if options[:max_link_length]
                  link_text = truncate(link_text, :length=>options[:max_link_length])
                end

                content_tag(:a, link_text, link_attributes.merge('href' => href), !!options[:sanitize]) + punctuation.reverse.join('')
              end
            end
          end

          def escape(href)
            # escape_once doesn't escape single-quotes but we need to since we're
            # potentially putting content in an attribute tag
            escape_once(href).gsub("'", '&#39;')
          end

          # Turns all email addresses into clickable links.  If a block is given,
          # each email is yielded and the result is used as the link text.
          def auto_link_email_addresses(text, html_options = {}, options = {})
            text.gsub(AUTO_EMAIL_RE) do
              text = $&

              if auto_linked?($`, $')
                text.html_safe
              else
                display_text = (block_given?) ? yield(text) : text

                unless options[:sanitize] == false
                  text         = sanitize(text)
                  display_text = sanitize(display_text) unless text == display_text
                end
                mail_to text, display_text, html_options
              end
            end
          end

          # Detects already linked context or position in the middle of a tag
          def auto_linked?(left, right)
            (left =~ AUTO_LINK_CRE[0] and right =~ AUTO_LINK_CRE[1]) or
              (left.rindex(AUTO_LINK_CRE[2]) and $' !~ AUTO_LINK_CRE[3])
          end

          def conditional_sanitize(target, condition, sanitize_options = {})
            condition ? sanitize(target, sanitize_options) : target
          end

          def conditional_html_safe(target, mark_as_html_safe)
            mark_as_html_safe ? target.html_safe : target
          end
      end
    end
  end
end
