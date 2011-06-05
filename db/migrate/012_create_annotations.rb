# see
# contexts in general : http://www.w3.org/2001/12/attributions/
# to see a not-really-polymorphic relation : http://blog.hasmanythrough.com/2006/4/3/polymorphic-through

module ActiveRecord
  module ConnectionAdapters
    module SchemaStatements
       def add_index(table_name, column_name, options = {})
        column_names = Array(column_name)
        index_name   = index_name(table_name, :column => column_names.first)

        if Hash === options # legacy support, since this param was a string
          index_type = options[:unique] ? "UNIQUE" : ""
          index_name = options[:name] || index_name
        else
          index_type = options
        end
        quoted_column_names = column_names.map { |e|
          case e
          when Array
            quote_column_name(e.shift) + e.join(' ')
          else
            quote_column_name(e)
          end
        }.join(", ")
        execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{table_name} (#{quoted_column_names})"
      end
    end
  end
end

$create_annotations_with_indices = true;

class CreateAnnotations < ActiveRecord::Migration

  def self.up()
    begin
      down()
    rescue Exception
    end
    create_table :annotation_assertions do |t|
      t.column :context_id, :integer
      t.column :subject_reference_type, :string
      t.column :subject_reference_id, :integer, :default => 0
      t.column :subject_text, :text
      t.column :predicate_reference_type, :string
      t.column :predicate_reference_id, :integer, :default => 0
      t.column :predicate_text, :text
      t.column :object_reference_type, :string
      t.column :object_reference_id, :integer, :default => 0
      t.column :object_text, :text
            
      t.column :created_at, :datetime  # provenance is by virtue of the context
      t.column :updated_at, :datetime
    end
    
    create_table :annotation_contexts do |t|
      t.column :annotator_type, :string
      t.column :annotator_id, :integer
      t.column :name, :text
      
      t.column :created_at, :datetime # provenance is by virtue of the annotator
      t.column :updated_at, :datetime
    end

    # compute a key length so as to fit class names.
    # make it a multiple of 8 bytes
    def self.compute_key_length()
      max_length = 0
      max_name = ""
      ObjectSpace.each_object(Module){|o|
        name = o.name # ! REXML::FUnctions has a null name !
        if (name && name.length > max_length)
          max_name = o.name
          puts("next max: #{max_name}")
          max_length = max_name.length  
        end
      }
      # not a power of two return 2 ** ((Math.log(max_length)/Math.log(2)).ceil)
      8 * ((max_length / 8.0).ceil)
    end
    
    key_length = "(#{self.compute_key_length()})"
    
    if $create_annotations_with_indices
#    # context-scoped, assertion indices combining ((object + atom) x (object = atom))
#    add_index(:annotation_assertions, [:context_id,
#                                       [:subject_reference_type, key_length], :subject_reference_id,
#                                       [:predicate_reference_type, key_length], :predicate_reference_id                            ],
#                                      :unique => true, :name=> :attributed_that_oo_index)
#    add_index(:annotation_assertions, [:context_id,
#                                                                                                         [:subject_text, key_length],
#                                       [:predicate_reference_type, key_length], :predicate_reference_id                            ],
#                                      :unique => true, :name=> :attributed_that_ao_index)
    # subscribers are ((Journal + Group) x 'subscribed' x ?)
    # read time is ((Journa + Group + Entry) x :read_time x ?)
    add_index(:annotation_assertions, [:context_id,
                                       [:subject_reference_type, key_length], :subject_reference_id,
                                                                                                         [:predicate_text, key_length]],
                                       :unique => true, :name=> :attributed_that_oa_index)
#    add_index(:annotation_assertions, [:context_id,
#                                                                                                         [:subject_text, key_length],
#                                                                                                         [:predicate_text, key_length]],
#                                      :unique => true, :name=> :attributed_that_aa_index)
#    
#    # context-free that indices combining ((object + atom) x (object = atom))
#    add_index(:annotation_assertions, [[:subject_reference_type, key_length], :subject_reference_id,
#                                       [:predicate_reference_type, key_length], :predicate_reference_id],
#                                       :name=> :that_oo_index)
#    add_index(:annotation_assertions, [                                                                  [:subject_text, key_length],
#                                       [:predicate_reference_type, key_length], :predicate_reference_id                            ],
#                                       :name=> :that_ao_index)
#    add_index(:annotation_assertions, [[:subject_reference_type, key_length], :subject_reference_id,
#                                                                                                         [:predicate_text, key_length]],
#                                       :name=> :that_oa_index)                                  
#    add_index(:annotation_assertions, [                                                                  [:subject_text, key_length],
#                                                                                                         [:predicate_text, key_length]],
#                                       :name=> :that_aa_index)         
#                                                                  
#    # context-free which indices combining ((object + atom) x (object = atom))
#    add_index(:annotation_assertions, [[:predicate_reference_type, key_length], :predicate_reference_id,
#                                       [:object_reference_type, key_length], :object_reference_id],
#                                       :name=> :which_oo_index)
#    add_index(:annotation_assertions, [[:predicate_reference_type, key_length], :predicate_reference_id,
#                                                                                                         [:object_text, key_length]],
#                                       :name=> :which_oa_index)
#    add_index(:annotation_assertions, [[:object_reference_type, key_length], :object_reference_id,
#                                                                                                         [:predicate_text, key_length]],
#                                       :name=> :which_ao_index) 
     # favorites are (? x 'favorite' z ('public' + ' private'))                            
     add_index(:annotation_assertions, [                                                                  [:predicate_text, key_length],
                                                                                                          [:object_text, key_length]],
                                        :name=> :which_aa_index)
#         
#    add_index(:annotation_assertions, [[:subject_reference_type, key_length], :subject_reference_id                                 ],
#                                       :name=> :about_o_index)
#    add_index(:annotation_assertions, [                                                                  [:subject_text, key_length]],
#                                       :name=> :about_a_index)
#                                       
#    add_index(:annotation_assertions, [[:object_reference_type, "(80)"], :object_reference_id,                                  ],
#                                       :name=> :of_o_index)
#    add_index(:annotation_assertions, [                                                                  [:object_text, key_length]],
#                                       :name=> :of_a_index)
#
#    add_index(:annotation_contexts, [[:annotator_type, "(80)"], :annotator_id,                                  ],
#                                       :name=> :annotator_index)
    end
                                       
    
    add_column(:users, :annotation_context_id, :integer)

    def self.initialize_annotations()
      Annotation::Assertion.create(:context_id=> 1,
                                   :subject_text => '/',
                                   :predicate_text=> '/',
                                   :object_text=> '/')
      site_context = Annotation::Context.create(:annotator_type=>'Annotation::Assertion', :annotator_id=> '1', :name=> "/")
      site_context.assert('Journal', :entry_sort, {'column'=> 'date', 'order'=> 'DESC'})
      site_context.assert('User', :journal_sort, {'column'=> 'updated_at', 'order'=> 'DESC'})
      site_context.assert('User', :group_sort, {'column'=> 'updated_at', 'order'=> 'DESC'})
      site_context.assert('User', :user_sort, {'column'=> 'updated_at', 'order'=> 'DESC'})
    end
    
    self.initialize_annotations()
  end


  def self.down
    # remove_index(:annotation_assertions, :assertion_key)
    # remove_index(:annotation_assertions, :relation_key)
    # remove_index(:annotation_assertions, :subject_key)
    # remove_index(:annotation_assertions, :object_key)
    
    drop_table :annotation_assertions
    drop_table :annotation_contexts
    
    remove_column(:users, :annotation_context_id)
  end
end

