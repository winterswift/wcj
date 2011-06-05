#!/usr/bin/env ruby

require "graphviz"
require "annotation"

module Annotation 

  class Grapher
  
    attr_reader :graph
    attr_reader :node_registry
    attr_reader :edge_registry
    attr_reader :encoding
    attr_reader :pathname
    attr_writer :logger
    
    @@defaults = {
      :encoding => 'svg',
      :options => {},
      :states => [:active?, :published?]
    }
      
    def initialize(options = {})
      if (options.kind_of?(String))
        options = {:name => options}
      end
      options = @@defaults.clone.merge(options)
      @name = (options[:name] || 'untitled')
      @graph = GraphViz::new(@name, options[:options])
      @states = options[:states]
      @node_registry = Hash.new()
      @edge_registry = Hash.new()
      @max_depth = options[:depth]
      @encoding = options[:encoding]
      @pathname = (options[:pathname] || "#{@name}-#{time_label(Time.new)}.#{@encoding}")
      @depth = 0
    end
    
    def time_label(datum)
      datum.strftime('%Y%m%dT%H%M%SZ')
    end
    
    def graph_label(datum)
      case datum
      when ActiveRecord::Base
        "#{datum.class.name}/#{datum.id}"
      when Time
        time_label(datum)
      else
        datum.to_s
      end
    end
    
    def info(string)
      if @logger
        @logger.info(string)
      end
    end
    
    def debug(string)
      if @logger
        @logger.debug(string)
      end
    end
        
    def visible?(datum)
      @states.each{|predicate|
        if (datum.respond_to?(predicate))
          if (datum.send(predicate))
            return(true)
          end
        end
      }
      (datum ? true : false)
    end
    
    def graph_attributes(datum)
      if datum.respond_to?(:graph_attributes)
        datum.graph_attributes(self)
      elsif datum.respond_to?(:comment)
        comment_graph_attributes(datum)
      else
        {'label'=> graph_label(datum)}
      end
    end
    
    def add_node(datum, attributes = nil)
      @graph.add_node("node_#{datum.object_id}", (attributes || graph_attributes(datum)))
    end
    
    def graph_node(datum, attributes = nil)
      debug("graph_node(#{datum}, #{attributes.inspect})")
      if (datum.kind_of?(GraphViz::Node))
        datum
      elsif visible?(datum)
        node = @node_registry[datum]
        unless node
          node = add_node(datum, attributes)
          @node_registry[datum] = node
          if (node.respond_to?('build_graph'))
            if nil == @max_depth
              datum.build_graph(self)
            elsif ( (@depth += 1) <= @max_depth )
              datum.build_graph(self)
              @depth -= 1
            end
          elsif node.respond_to?('comment')
            comment_build_graph(node)
          else
             if (datum.methods.include?('build_graph'))
               datum.build_graph(self)
             end
          end
        end
        node
      end
    end
    
    def graph_edge(from, to, args = {})
      from = graph_node(from)
      to = graph_node(to)
      if (from && to)
        edge = [from, to]
        unless (@edge_registry[edge])
          @edge_registry[edge] = edge
          @graph.add_edge(from, to, args)
        end
      end
    end
  
    def write(options = {})
      pathname = options[:pathname] || @pathname
      encoding = options[:encoding] || @encoding
      Tempfile.open(pathname){|io|
        @graph.output('output' => encoding){|pipe|
          while (buffer = pipe.read(1024))
            io.write(buffer)
          end
        }
        pathname = io.path
      }
      pathname
    end
    
    # was imposible to exend the comment class in dev mode
    def comment_graph_attributes(comment)
      text = comment.comment || ""
      time = comment.created_at
      label = "[#{time.strftime('%Y%m%d')}] #{text[0...15]}#{text.length > 15 ? '...' : ''}"
      base = { 'label' => label, 'shape' => 'rectangle' }
      if ((commentable = comment.commentable) && commentable.respond_to?(:url))
        base['URL'] = commentable.url()
      end
      base
    end
    
    def comment_build_graph(comment)
      self.debug("build_graph(#{self}/#{self.id}")
      self.graph_edge(comment, comment.commentable(), {'color' => 'purple', 'label'=> 'about'})
      self.graph_edge(comment.user(), comment, {'label'=> 'made', 'color' => 'blue'})
      comment
    end
  end
  
end


