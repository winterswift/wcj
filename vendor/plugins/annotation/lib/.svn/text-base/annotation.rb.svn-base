#!ruby
#
# 20070107  james.anderson  for persistent settings
# 20060108  james.anderson  added guards for deleted references. do it lazily to
#  support #307 without requiring dependency
#
# Annotation::Context
#   belongs_to :annotator, :polymorphic => true
#   has_many :assertions, :class_name=> 'Annotation::Assertion', :dependent => :destroy
#
# Annotation::Annotator
#   has_many :annotation_contexts, :as=> :annotator, :dependent => :destroy,
#                                  :class_name=> 'Annotation::Context'
#   has_many :assertions, :through=> :annotation_contexts,
#                         :class_name=> 'Annotation::Assertion'
#
# Annotation::Annotatable
#   has_many :subject_assertions, :class_name=> 'Annotation::Assertion', :dependent => :destroy,
#                                 :as => :subject_reference
#   has_many :predicate_assertions, :class_name=> 'Annotation::Assertion', :dependent => :destroy,
#                                   :as => :predicate_reference
#   has_many :object_assertions, :class_name=> 'Annotation::Assertion', :dependent => :destroy,
#                                :as => :object_reference
#
# Assertion < ActiveRecord::Base
#  
#   belongs_to :annotation_context, :class_name=> 'Annotation::Context', :foreign_key=> 'context_id'
#   belongs_to :subject_reference, :polymorphic=> true
#   belongs_to :predicate_reference, :polymorphic=> true
#   belongs_to :object_reference, :polymorphic=> true

module Annotation

  # Annotation::Annotatable adds the assertion_id method to a class, to produce a default
  # assertion id comprising the class and instance id
  # 
  module Annotatable

    # ensure that the class includs ActiveRecord::Base, in order that the .id work.
    def self.included(base)
      case
      when base.ancestors.include?(ActiveRecord::Base)
        base.extend(ConstructorMethods)
        base.initialize_class()
      when base.method_defined?(:id)
      else
        fail(ArgumentError, "Not an Annotatable class: #{base}.")
      end
      super(base)
    end
    
    module ConstructorMethods
      def initialize_class()
        has_many :subject_assertions, :class_name=> 'Annotation::Assertion', :dependent => :destroy,
                                      :as => :subject_reference
        has_many :predicate_assertions, :class_name=> 'Annotation::Assertion', :dependent => :destroy,
                                      :as => :predicate_reference
        has_many :object_assertions, :class_name=> 'Annotation::Assertion', :dependent => :destroy,
                                      :as => :object_reference
      end
    end
    
    def reference_assertions()
      @reference_assertions ||= (self.subject_assertions + self.predicate_assertions + self.object_assertions)
    end
        
  end


  # reify the context names in order to support extension
  class Context < ActiveRecord::Base
    USE_CACHE = false
    @use_cache = USE_CACHE
    
    set_table_name 'annotation_contexts'
    belongs_to :annotator, :polymorphic => true
    has_many :assertions, :class_name=> 'Annotation::Assertion', :dependent => :destroy,
                          :foreign_key=> 'context_id'
    
    # validates_presence_of :name
    validates_uniqueness_of :name, :scope => [:annotator_type, :annotator_id], :allow_nil=> true
    
    # in the context of a Context, the canonical value of a module is its name,
    # which means that a relation involving a class is the same as one with its
    # name. otherwise, the datum is used, as is.
    # this determines the key in a cache only (see Assertion.canonical)
    def self.canonical(datum)
      if (datum.kind_of?(Module))
        datum.name
      else
        datum
      end
    end
    
#    def self.new_annotation_context(annotator, name = "#{annotator.class.name}/#{annotator.id()}")
#      context = self.new()
#      context.annotator=(annotator)
#      context.name=(name)
#      unless (!annotator || annotator.new_record?())
#        puts("saving new context: #{context} / #{annotator}")
#        context.save!()
#        puts("saved")
#      else
#        puts("save deferred.")
#      end
#      context
#    end
    
    def build_graph(grapher)
      grapher.debug("Context#build_graph(#{self}/#{self.id})")
      # do not present the context itself, just the annotator
      if (annotator = self.annotator)
        self.assertions.each{|a| annotator.build_graph_link(grapher, a) }
      end
      self
    end
    
    def clear()
      cache().clear()
    end
    
    # return a single (S P O) triple
    # too ambiguous - use assertion_that
#    def asserted(subject, predicate)
#      if (assertion = assertion_that(subject, predicate))
#        logger.debug("asserted: #{self.name}: [#{subject} . #{predicate} . #{assertion.object}]")
#        assertion
#      end
#    end
    
    # create a new triple. extends existing relations if the value is not present
    # returns the triple
    def create_assertion(subject, predicate, object)
      Assertion.create_assertion(self, subject, predicate, object)
    end
    
    # checks a cache for the pair and updates it if found. otherwise it creates a new one and caches it.
    # flushed the assertion and returns the asserted argument object
    def assert(subject, predicate, object)
      assertion = assertion_that(subject, predicate) # canonicalization in assertion_that
      assertion.object=(Context.canonical(object))
      # perform eager save if the context is already persistent
      if !(self.new_record?())
        assertion.save!()
      end
      object
    end
    
    def deny(subject, predicate, object = nil)
      destroy_assertion(subject, predicate, object)
    end
    
    def destroy_assertion(subject, predicate, object)
      find_assertions(subject, predicate, object, :all).each{|a| a.destroy()}
    end
      
    
    # returns a single (subject x predicate) assertion instance, with cache based on the pair
    def assertion_that(subject, predicate)
      subject = Context.canonical(subject)
      predicate = Context.canonical(predicate)
      key = [subject, predicate, nil]
      if (@use_cache && result = cache().fetch(key, nil))
        result
      elsif (result = _find_assertions(subject, predicate, nil, :first))
        cache[key] = result
      else
        cache[key] = _new_assertion(subject, predicate, nil)
      end
    end
    
    def self.global_assertion(subject, predicate)
      subject = Context.canonical(subject)
      predicate = Context.canonical(predicate)
      self._find_global_assertions(subject, predicate, nil, :first)
    end
    
    def new_assertion(s, p, o)
      _new_assertion(s, p, o)
    end
    
    def find_assertions(s, p, o, specificity)
      result = _find_assertions(s, p, o, specificity)
      logger.debug("find_assertions: result: #{result}")
      result
    end
    
    def self.find_global_assertions(s, p, o, specificity)
      result = self._find_global_assertions(s, p, o, specificity)
      logger.debug("find_global_assertions: result: #{result}")
      result
    end

    def find_assertions_of(o, specificity = :all)
      _find_assertions(nil, nil, o, specificity)
    end
    
    def find_assertions_predicating(p, specificity = :all)
      _find_assertions(nil, p, nil, specificity)
    end
    
    def find_assertions_about(s, specificity = :all)
      _find_assertions(s, nil, nil, specificity)
    end
    
    def find_assertions_that(s, p, specificity = :all)
      _find_assertions(s, p, nil, specificity)
    end
    
    def find_assertions_relating(s, o, specificity = :all)
      _find_assertions(s, nil, o, specificity)
    end
    
    def find_assertions_which(p, o, specificity = :all)
      _find_assertions(nil, p, o, specificity)
    end
    

    # an assertion context can have only one annotation context: itself 
    def annotation_context()
      self
    end
    
    def to_s()
      "#(#{self.class.name} #{annotator_type}/#{annotator_id} #{name})"
    end
    
    private
    
    def cache()
      @cache ||= {}.with_indifferent_access
    end
    
    # instantiate a new assertion in this context. build, rather than create,
    # and save it only if all constituents are present.
    def _new_assertion(subject, predicate, object)
      # puts("new assertion")
      assertion = self.assertions.build()
      assertion.subject = subject if subject
      assertion.predicate = predicate if predicate
      assertion.object = object if object
      if (subject && predicate && object)
        assertion.save()
      end
      assertion
    end
    
    def _find_assertions(subject, predicate, object, specificity)
      Annotation::Assertion.find_assertions(self, subject, predicate, object, specificity)
    end
     
    def self._find_global_assertions(subject, predicate, object, specificity)
      Annotation::Assertion.find_assertions(nil, subject, predicate, object, specificity)
    end
     
  end
  
  
  module Annotator
    
    def self.included(base)
      super(base)
      base.extend(ConstructorMethods)
      base.initialize_class()
      # unless this is here, for the first request, Annotation binds
      #   Assertion,Examiner,Annotatable,Context,Annotator
      # but on every successive, only the modules included in the controllersw remain
      #   Examiner,Annotatable,Annotator
      # while the others, Examiner, Context have been unbound.
      # it also does not help, to just bind the module extra - the module's methods disappear
      unless (Annotation.const_defined?("Context") &&
              Annotation::Context.instance_methods.include?('assert'))
        load(__FILE__)
      end
    end
    
    module ConstructorMethods
      def initialize_class()
        # this exhibited some not-so-useful behaviour - created new instances on refernce, but didn't
        # save the annotator to reflect that, so
        has_one :annotation_context, :as=> :annotator, :class_name=> 'Annotation::Context',
                                     :foreign_key=> 'annotation_context_id'
        has_many :annotation_contexts, :as=> :annotator, :dependent => :destroy,
                                       :class_name=> 'Annotation::Context'
        # through assertions fail, perhaps because one belongs to is on the assertion, rather
        # than both being on the context:
        # ActiveRecord::StatementInvalid: Mysql::Error: #42S22Unknown column 'annotation_contexts.context_id' in 'on clause': SELECT annotation_assertions.* FROM annotation_assertions  INNER JOIN annotation_contexts ON annotation_assertions.id = annotation_contexts.context_id    WHERE (annotation_contexts.annotator_id = 29 AND annotation_contexts.annotator_type = 'Journal') 
        #
        # has_many :assertions, :through=> :annotation_contexts,
        #                       :class_name=> 'Annotation::Assertion'
                              
        extend Annotator::ClassMethods
        include Annotation::Annotatable  # to make sure to get the assertion_id

        before_save :integrate_annotation_context
      end
    end
    
    # This module contains class methods, to extend an including classes
    module ClassMethods
      # Helper method to lookup for comments for a given object.
      # This method is equivalent to obj.comments.
      def find_annotation_contexts_by(annotator)
        annotator_type = ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s
       
        Annotation::Context.find(:all,
          :conditions => ["annotator_id = ? and annotator_type = ?", annotator.id, annotator_type],
          :order => "name DESC"
        )
      end
      
      # Helper class method to lookup assertiond by an agent
      def find_assertions_by(annotator) 
        annotator_type = ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s
        
        Annotation::Assertion.find(:all,
          :include=> :context,
          :conditions => ["annotator_id = ? and annotator_type = ?", annotator.id, annotator_type],
          :order => "annotation_assertions.created_at DESC"
        )
      end
    end
    
    # instance methods
    
    # ensure that the current annotation context is in the collection
    def integrate_annotation_context()
      if (context = self.annotation_context)
        unless (self.annotation_contexts.include?(context))
          self.annotation_contexts << context
        end
      end
    end
    
    # return an existing annotation context or create a new one
    # nb. if called just annotation_context, it seems like these get ignored or overridden
    def current_annotation_context()
      context = self.annotation_context()
      unless (context)
        context = self.create_annotation_context()
        logger.debug("creating annotation context: #{self}/#{self.id}")
      end
      context
    end
    
#    def set_annotation_context(new_context)
#      unless (new_context.kind_of?(Annotation::Context))
#        raise(ArgumentError, "invalid annotation context: #{new_context}.")
#      end
#      unless annotation_contexts.include?(new_context)
#        annotation_contexts << new_context
#      end
#      @annotation_context = new_context
#      self[:annotation_context_id] = new_context.id
#      logger.info("setting annotation context: #{self.inspect}")
#      puts("setting annotation context: #{self.inspect}")
#      unless (self.new_record?()) # defer the save 
#        begin
#          save!()
#        rescue Exception
#          logger.warn("could not save annotator when updating context: #{self}/#{self.id} : #{$!}.")
#        end
#      else
#        puts("deferring context save")
#      end
#      new_context
#    end
#    
#    alias :annotation_context= :set_annotation_context
    
    def assertions()
      self.class.assertions_by(self)
    end
    
    
    # set an assertion value in the current context.
    # this constrains the relation to a single triple keyed by (subject x predicate)
    # and uses a cache
    def assert(subject, predicate, object)
      context = current_annotation_context()
      logger.debug("Annotator#assert: context #{context}.(#{subject} #{predicate} #{object})")
      value = context.assert(subject, predicate, object)
      value
    end
    
    # delete specified assertion(s), when called without an object,
    # it deletes all for the subject and predicate
    def deny(subject, predicate, object=nil)
      current_annotation_context().deny(subject, predicate, object)
    end
    
    # add an assertion to the context. 
    # this generates multiple (subject x predicate) triples
    def create_assertion(subject, predicate, object)
      current_annotation_context().create_assertion(subject, predicate, object)
    end

    # add an assertion to the context. 
    # this generates multiple (subject x predicate) triples
    def destroy_assertion(subject, predicate, object)
      current_annotation_context().destroy_assertion(subject, predicate, object)
    end

    # return an assertion value in the current context
    # as a special case, allows keyword spec and default to specificity :first
    # for (subject x predicate) assertions
    def asserted(subject = nil, predicate = nil, object = nil,
                 specificity = ((subject && predicate) ? :first : :all),
                 context = current_annotation_context())
      if (subject.kind_of?(Hash))
        object = subject.fetch(:object, object)
        predicate = subject.fetch(:subject, subject)
        specificity = subject.fetch(:specificity, specificity)
        subject = subject.fetch(:subject, nil)
      end
      
      begin
        if (subject)
          if (predicate)
            assertions_that(subject, predicate, specificity, context)
          elsif (object)
            assertions_relating(subject, object, specificity, context)
          else
            assertions_about(subject, specificity, context)
          end
        elsif (predicate)
          if (object)
            assertions_which(predicate, object, specificity, context)
          else
            assertions_predicating(predicate, specificity, context)
          end
        elsif (object)
          assertions_of(object, specificity, context)
        else
          fail(ArgumentError, "one of aubject, object, predicate must be supplied.")
        end
      rescue Exception
        ActiveRecord::Base.logger.debug("asserted: #{subject} #{predicate} : failed #{$!}")
        nil
      end
    end
    
    # return assertion instances from the specified context which match the
    # argument (subject x predicate x object) constraints.
    # specificity is :all for the extent, or :first for the first instance
    # the default context is the assertor's current context.
    # if Nil is supplied, the global assertions are returned.
    def find_assertions(subject, predicate, object, specificity, context = current_annotation_context())
      if context
        context.find_assertions(subject, predicate, object, specificity)
      else
        Annotation::Context.find_global_assertions(subject, predicate, object, specificity)
      end
    end
    
    def assertions_about(s, specificity = :all, context = current_annotation_context())
      case (result = find_assertions(s, nil, nil, specificity, context))
      when Annotation::Assertion
        result = pair_if(result.predicate, result.object)
      when Array
        result = result.map{|a| pair_if(a.predicate, a.object)}
        result.compact!
      end
      result
    end
    
    def assertions_of(o, specificity = :all, context = current_annotation_context())
      case (result = find_assertions(nil, nil, o, specificity, context))
      when Annotation::Assertion
        result = pair_if(result.subject, result.predicate)
      when Array
        result = result.map{|a| pair_if(a.subject, a.predicate) }
        result.compact!
      end
      result
    end
    
    # return the set of subject which have any value for a property
    def assertions_predicating(p, specificity = :all, context = current_annotation_context())
      case (result = find_assertions(nil, p, nil, specificity, context))
      when Annotation::Assertion
        result = pair_if(result.subject, result.object)
      when Array
        result = result.map{|a| pair_if(a.subject, a.object) }
        result.compact!
      end
      result
    end
    
    # return the set of values for a given subject's property
    # this is for multi-valued assertions which are not stored atomically
    def assertions_that(s, p, specificity = :all, context = current_annotation_context())
      case (result = find_assertions(s, p, nil, specificity, context))
      when Annotation::Assertion
        result = result.object
      when Array
        result = result.map{|a| a.object }
        result.compact!
      end
      result
    end
    
    def annotators_that(s, p, specificity = :all, context = nil)
      case (result = find_assertions(s, p, nil, specificity, context))
      when Annotation::Assertion
        result = result.context.annotator
      when Array
        result = result.map{|a| a.context.annotator }
        result.compact!
      end
      result
    end
    
    # return the collection of subject WHICH have a specific property value
    def assertions_which(p, o, specificity = :all, context = current_annotation_context())
      result = find_assertions(nil, p, o, specificity, context)
      case (result)
      when Annotation::Assertion
        result = result.subject
      when Array
        result = result.map{|a| a.subject }
        result.compact!
      end
      logger.debug("assertions_which : #{result.inspect}")
      result
    end
    
    def assertions_relating(s, o, specificity = :all, context = current_annotation_context())
      result = find_assertions(s, nil, o, specificity, context)
      case (result)
      when Annotation::Assertion
        result = result.predicate
      when Array
        result = result.map{|a| a.predicate }
        result.compact!
      end
      logger.debug("assertions_relating : #{result.inspect}")
      result
    end
    
    
    # the base method just graphs the contexts
    def build_graph(grapher)
      self.annotation_contexts.each{|i| i.build_graph(grapher) }
    end
    
    def build_graph_link(grapher, assertion)
      subject = assertion.subject
      predicate = assertion.predicate
      object = assertion.object
      case predicate
      when :read_time, 'read_time'
        grapher.graph_edge(self, subject, {'label' => "READ @ #{grapher.graph_label(object)}",
                                           'color' => 'red', 'style'=> 'dotted'})
      else
        grapher.graph_edge(self, subject)
        grapher.graph_edge(subject, object, 'label' => grapher.graph_label(predicate))
      end
    end
    
    private
    
    def pair_if(a, b)
      ( a && b ) ? [a, b] : nil
    end
 
  end

 
  # class methods perform the access
  # instance is a cache for the user id only and a handle on the class methods
 
  class Assertion < ActiveRecord::Base
  
    set_table_name 'annotation_assertions'
  
    belongs_to :context, :class_name=> 'Annotation::Context'
    belongs_to :subject_reference, :polymorphic=> true
    belongs_to :predicate_reference, :polymorphic=> true
    belongs_to :object_reference, :polymorphic=> true

   
    def self.canonical_text(datum)
      if (datum.kind_of?(Module))
        datum.name.to_s
      elsif (datum.kind_of?(String))
        datum
      elsif (datum.kind_of?(Symbol))
        datum.to_s
      elsif (nil == datum)
        nil
      elsif datum.kind_of?(Annotation::Annotatable)
        fail(ArgumentError, "attempt to encode as an atomic value: #{datum}.")
      else
        datum.to_yaml
      end
    end
    
    def self.find_assertions(context, subject, predicate, object, specificity)
      unless (context || subject || predicate || object)
        fail(ArgumentError, "One of context, subject, predicate, object must be specified")
      end
      unless [:all, :first].include?(specificity)
        fail(ArgumentError, "Invalid specificity: #{specificity}.")
      end
      
      if (context)
        args = [context.id]
        query = "context_id = ?"
      else
        args = []
        query = ""
      end
      
      case 
      when subject.kind_of?(Annotation::Annotatable)
        query << " AND" if (args.length > 0)
        query << " subject_reference_type = ? AND subject_reference_id = ? "
        args << subject.class.name
        args << subject.id
      when nil == subject # no constraint
      else
        query << " AND" if (args.length > 0)
        query << ' subject_text = ?'
        args << Assertion.canonical_text(subject)
      end
      
      case 
      when predicate.kind_of?(Annotation::Annotatable)
        query << " AND" if (args.length > 0)
        query << " predicate_reference_type = ? AND predicate_reference_id = ? "
        args << predicate.class.name
        args << predicate.id
      when nil == predicate # no constraint
      else
        query << " AND" if (args.length > 0)
        query << ' predicate_text = ?'
        args << Assertion.canonical_text(predicate)
      end
      
      case
      when nil == object # no constraint
      when object.kind_of?(Annotation::Annotatable)
        query << " AND" if (args.length > 0)
        query << " object_reference_type = ? AND object_reference_id = ? "
        args << object.class.name
        args << object.id
      else
        query << " AND" if (args.length > 0)
        query << ' object_text = ?'
        args << Assertion.canonical_text(object)
      end
      
      logger.debug("Assertion.find_assertions: #{specificity} [#{([query] + args).join(' ')}]")
      # puts("Assertion.find_assertions: #{specificity} [#{([query] + args).join(' ')}]")
      begin
        result = self.find(specificity, :conditions=> ([query] + args))
      rescue ActiveRecord::RecordNotFound
        case specificity
        when :all
          result = []
        when :first
          result = nil
        end
      end
      logger.debug("find_assertion: [#{ (:all == specificity) ? result.join(' ') : result}]")
      result
    end
    
    def self.new_assertion(context, subject, predicate, object = nil)
      # puts("self.new_assertion #{subject} #{predicate} #{object}")
      if (result = find_assertions(context, subject, predicate, object, :first))
        # puts("self.new_assertion: found: #{result}")
        result
      else
        assertion = new()
        # puts("self.new_assertion: new #{new}")
        case
        when context.kind_of?(Integer)
          assertion.context_id = context;
        when context.kind_of?(Annotation::Context)
          assertion.context = context
        else
          fail(ArgumentError, "invalid context: #{context}")
        end
        
        assertion.subject = subject;
        assertion.predicate = predicate;
        assertion.object = object;
        assertion
      end
    end
    
    def self.create_assertion(context, subject, predicate, object)
      assertion = self.new_assertion(context, subject, predicate, object)
      unless (!context || context.new_record?())
        assertion.save()
      end
      assertion
    end
    
    def subject
      @subject ||= ( valid_reference_id?(self[:subject_reference_id]) ?
                     begin
                       self.subject_reference()
                     rescue ActiveRecord::RecordNotFound
                       # the reference has disappeared, destroy this record
                       self.subject_reference=(nil)
                       nil
                     end :
                     ((text = self[:subject_text]) ? (("" == text) ? nil : YAML::load(text)) : nil) )
    end
    
    def subject=(new_subject)
      @subject = new_subject
      # modifying an existing assertion can write-through, unless the
      # record is being created.
      case
      when (self.new_record?)
      when (nil == new_subject)
        self.destroy unless (self.frozen?)
      end
      new_subject
    end
    
    def encode_subject()
      case
      # 20070117 ? case directly on class failed for journals
      when @subject.kind_of?(Annotation::Annotatable)
        self.subject_reference=(@subject)
        self.subject_text=('')
      when nil == @subject # delete the instance unless new
        self.subject_reference=(nil)
        self.subject_text=('')
      else
        self.subject_reference=(nil)
        self.subject_text=(Assertion.canonical_text(@subject))
      end
    end
    
    def predicate
      @predicate ||= ( valid_reference_id?(self[:predicate_reference_id]) ?
                       begin
                         self.predicate_reference()
                       rescue ActiveRecord::RecordNotFound
                         # the reference has disappeared, destroy this record
                         self.predicate_reference=(nil)
                         nil
                       end :
                       ((text = self[:predicate_text]) ? (("" == text) ? nil : YAML::load(text)) : nil) )
    end
     
    def predicate=(new_predicate)
      @predicate = new_predicate
      # modifying an existing assertion can write-through, unless the
      # record is being created.
      case
      when (self.new_record?)
      when (nil == new_predicate)
        self.destroy unless (self.frozen?)
      end
      new_predicate
    end
    
    def encode_predicate()
      case 
      when @predicate.kind_of?(Annotation::Annotatable)
        self.predicate_reference=(@predicate)
        self.predicate_text=('')
      when nil == @predicate # delete the instance
        self.predicate_reference=(nil)
        self.predicate_text=('')
      else
        self.predicate_reference=(nil)
        self.predicate_text=(Assertion.canonical_text(@predicate))
      end
    end
    
    def object
      @object ||= ( valid_reference_id?(self[:object_reference_id]) ?
                    begin
                      self.object_reference()
                    rescue ActiveRecord::RecordNotFound # the reference has disappeared
                       self.object_reference=(nil)
                       nil
                     end :
                    ((text = self[:object_text]) ? (("" == text) ? nil : YAML::load(text)) : nil) )
    end
    
    def object=(new_object)
      @object = new_object# modifying an existing assertion can write-through, unless the
      # record is being created.
      case
      when (self.new_record?)
      when (nil == new_object)
        self.destroy unless (self.frozen?)
      end
      new_object
    end
    
    def encode_object()
      case 
      when @object.kind_of?(Annotation::Annotatable)
        self.object_reference=(@object)
        self.object_text=('')
      when nil == @object # delete the instance
        self.object_reference=(nil)
        self.object_text=('')
      else
        self.object_reference=(nil)
        self.object_text=(Assertion.canonical_text(@object))
      end
    end
    
    def before_save()
      encode_subject()
      encode_predicate()
      encode_object()
    end
    
    def to_s()
      s = (type = self[:subject_type]) ? "#{type}/#{self[:subject_id]}" : self.subject
      p= (type = self[:predicate_type]) ? "#{type}/#{self[:predicate_id]}" : self.predicate
      o = (type = self[:object_type]) ? "#{type}/#{self[:object_id]}" : self.object
      "#(#{self.class.name} #{context} [#{s} #{p} #{o}])"
    end
    
    def to_xml()
      def constituent_element(role, type, id, text)
        if type
          "<#{role} type='#{type}' id='#{id}' />"
        elsif text
          "<#{role} text='#{text}' />"
        else
          ""
        end
      end
      "<assertion>" +
      constituent_element('subject', self.subject_reference_type,  self.subject_reference_id,  self.subject_text) +
      constituent_element('predicate', self.predicate_reference_type,  self.predicate_reference_id,  self.predicatet_text) +
      constituent_element('object', self.object_reference_type,  self.object_reference_id,  self.object_text) +
      "</assertion>"
    end
    
    def to_html()
      def constituent_element(role, type, id, text)
        if text
          text =  text.gsub("\n", "|nl|")
        end
        "type: '#{type}' id: '#{id}' text: '#{text}'"
      end
      
      "<dt>#{constituent_element('subject', self.subject_reference_type,  self.subject_reference_id,  self.subject_text)}#{constituent_element('predicate', self.predicate_reference_type,  self.predicate_reference_id,  self.predicatet_text)}#{constituent_element('object', self.object_reference_type,  self.object_reference_id,  self.object_text)}</dt>" +
      "<dd><dl><dt>subject</dt><dd>#{self.subject}</dd>" +
               "<dt>predicate</dt><dd>#{self.predicate}</dd>" +
               "<dt>object</dt><dd>#{self.object}</dd>" +
               "</dl></dd>"
    end
    
    private
    
    def valid_reference_id?(x)
      (x.kind_of?(Integer) && (x > 0))
    end
    
  end
 
  module Examiner
  
    # setting accepts a sequence of contexts, a subject, a predicate (the setting name), and an optional sequence of facets
    # it iterates over the contexts, retrieving the respective assertion of the predicate wrt the subject.
    # an atomic assertion is returned immediately, a hash assertion is searched for facets
    def examine(context, subject, predicate, *facets)
      
      def reduce_object(value, facets)
        facets.each{|facet|
          case
          when (value.kind_of?(String) || value.kind_of?(Array))
            return nil
          when (value.respond_to?(:"[]"))
            unless (value = value[facet])
              return nil
            end
          else
            return nil
          end
        }
        value
      end
      
      def normalize(object)
        (object.kind_of?(Module) ? object.name : object)
      end
      
      contexts = (context.kind_of?(Array) ? context : [context])
      subjects =  (subject.kind_of?(Array) ? subject : [subject])
      predicate = normalize(predicate)
      value = nil
      logger.debug("?examine #{self}: [#{contexts.join(' ')}], #{subject}, #{predicate}, #{facets}");
      
      contexts.each{|context|
        case
        when (context.respond_to?(:asserted))
          subjects.each{|subject|
            case
            when ( value = reduce_object(context.asserted(normalize(subject), predicate), facets))
              logger.debug("examine for subject: = #{value}")
              return value
            when ( subject.kind_of?(Annotation::Annotatable) &&
                   (value = reduce_object(context.asserted(subject.class.name, predicate), facets)) )
              logger.debug("examine for subject class: = #{value}")
              return value
            when ( context.kind_of?(Annotation::Annotatable) &&
                   (value = (reduce_object(context.asserted(context, predicate), facets) ||
                             (context.class.name != subject.class.name &&
                              reduce_object(context.asserted(context.class.name, predicate), facets)))) )
              logger.debug("examine for context: = #{value}")
              return value
            end
          }
        when (context.respond_to?(:"[]"))
          if (value = reduce_object(context[predicate], facets))
            logger.debug("examine for hash: = #{value}")
            return value
          end
        when (nil == context)
          # nothing
        else
          logger.debug("examine: invalid context: #{context}.")
          nil
        end
      }

      logger.debug("examine: ! #{value.inspect}")
      value
    end
  end  
  
end

      
