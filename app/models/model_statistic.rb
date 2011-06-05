class ModelStatistic < ActiveRecord::Base
  belongs_to :instance, :polymorphic => true
  belongs_to :user, :polymorphic => true
  
  validates_presence_of :request_uri
  
  def graph_attributes(grapher)
    {}
  end
  
  def build_graph(grapher)
    grapher.debug("build_graph(#{self}/#{self.id}")
    user = self.user
    instance = self.instance
    from = self.referer || "NONE"
    to = self.request_uri || "UNKNOWN"
    if (instance)
      grapher.graph_edge(instance, to, {'label'=> "PAGE", 'color'=> 'gray', 'style'=> 'dotted'})
    end
    grapher.graph_edge(from , to , {'label'=> (user ? (user.login || user.id) : "ANON"),
                                           'color' => 'green', 'style'=> 'dashed'})
    self
  end
  
  def canonicalize_instance()
    changed_p = false
    ModelStatistic.canonicalize_uri(self.referer){|new|
     self.referer = new
     changed_p = true
    }
    ModelStatistic.canonicalize_uri(self.request_uri){|new|
      self.request_uri = new
      changed_p = true
    }
    if (changed_p)
      self.save!()
    end
    self
  end
    
  def self.canonicalize_uri(uri)
    if (uri)
      if (index = uri.index('?'))
        uri = uri[0...index]
        if (block_given?)
          yield(uri)
        end
      end
    else
      uri = ""
      if (block_given?)
        yield(uri)
      end
    end
    uri
  end
  
  def self.canonicalize_extent()
    self.find(:all).each{|i| i.canonicalize_instance() }
  end
  
end
