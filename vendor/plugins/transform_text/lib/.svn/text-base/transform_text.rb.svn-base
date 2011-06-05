require 'redcloth'
require 'bluecloth'
require 'rubypants'

module MakaluMedia #:nodoc:
  module Transform #:nodoc:
    def self.included(base)
      base.extend(ClassMethods) 
    end
    
    module ClassMethods
      def filter(fields = {}, text_filter = 'markdown', restrictions = [])
        write_inheritable_attribute(:filter_options,
        { :from_field         => fields.key,
          :to_field           => fields.value,
          :text_filter        => text_filter,
          :restrictions       => restrictions } )

        class_inheritable_reader :filter_options
        
        before_save :transform_text
        extend MakaluMedia::Filter::InstanceMethods
      end
      
    end
    
    module InstanceMethods
      def transform_text
        text = send(filter_options[:from_field])
        text_filter = send(filter_options[:text_filter])
        restrictions = send(filter_options[:restrictions])
        return '' if text.blank?
        return text if text_filter.blank?

        text_filter.split.each do |filter|
          case filter
          when "markdown":
            text = BlueCloth.new(text, restrictions).to_html
          when "textile":
            text = RedCloth.new(text, restrictions).to_html(:textile)
            if text[0..2] == "<p>" then text = text[3..-1] end
            if text[-4..-1] == "</p>" then text = text[0..-5] end
          when "smartypants":
            text = RubyPants.new(text).to_html
          when "simple_format":
            text = ActionView::Helpers::TextHelper.simple_format(text)
          end
        end
        
        write_attribute filter_options[:to_field], text
      end
    end
  end
end