#
# alex's original concept
# users/index redirects to users/list
#  users/list shows a list of all users
#  users/show display's a list of a user's journals
#  journals/index => journals/list
#  journals/list checks what type the browser is expecting (html or javascript) and returns a list of journals either rendered in the template or without the template
#  journals/show displays a list of all entries in that journal
#  groups/list displays a list of all groups
#  groups/show displays a list of all journals in that group
#  entries/show checks if the entry was found based on the date (parsed from the url) and either shows the existing entry or redirects to the create entry page
#
# 2006-11-15  james.anderson  added rss mappings
# 2006-11-19  james.anderson  restructured for preferred id designations and
#  explicit structure
# 2006-11-20  james.anderson  adjustments to order to correct precedence:
#  /**/id/:action shadowes a succeeding /**/id which means it must follow it
#  user-scoped group and journal listings
# 2006-11-21  james.anderson  corrected the _id regex
# 2006-11-24  james.anderson  elaborate the (id + login) x (id + urlname) taxonomy for the edit route 
# 2006-11-26  james.anderson  added owned_groups mapping for use in breadcrumb (adresses #45)
# 2006-11-27  james.anderson  added :action options to group, journal, user base resources.
# 2006-11-29  james.anderson  #55
# 

VERSIONS[__FILE__] = "$Id: routes.rb 889 2007-05-28 15:23:08Z niall $"

ActionController::Routing::Routes.draw do |map|
  map.home      '',
                :controller => 'pages'

  map.tos       'bots',
                :controller=> 'pages',
                :action=> 'bots'
                
  map.about     'about',
                :controller => 'pages',
                :action => 'about'

  map.ads       'advertising',
                :controller => 'pages',
                :action => 'advertising'

  map.privacy   'privacy',
                :controller => 'pages',
                :action => 'privacy'

  map.contact   'contact',
                :controller => 'pages',
                :action => 'contact'
  
  map.tos       'tos',
                :controller=> 'pages',
                :action=> 'tos'

  # account operations
  map.activate  'account/activate/:id',
                :controller => 'account',
                :action => 'activate'

  map.signup    'account/signup',
                :controller => 'account',
                :action => 'signup'

  map.login     'account/login',
                :controller => 'account',
                :action => 'login'

  map.login_to_group     'account/login/group',
                :controller => 'account',
                :action => 'login_to_group'

  map.signup_to_group     'account/signup/group',
                :controller => 'account',
                :action => 'signup_to_group'

  map.logout    'account/logout',
                :controller => 'account',
                :action => 'logout'

  map.dashboard 'dashboard',
                :controller => 'dashboard'

  # group operations : both direct and delegated from the user
  map.groups    'groups',
                :controller => 'groups',
                :action => 'list'
                
  map.rss       'groups/rss',
                :controller => 'groups',
                :action => 'rss'
                
  map.connect   'groups/list',
                :controller => 'groups',
                :action => 'list'
                
  map.connect   'groups/:group_id/show',
                :controller => 'groups',
                :action => 'show',
                :requirements => { :group_id => /[0-9]*/}
  map.connect   'groups/:urlname/show',
                :controller => 'groups',
                :action => 'show'
                
  map.group_id   'groups/:group_id',
                :controller => 'groups',
                :action => 'show',
                :requirements => { :group_id => /[0-9]*/}
  map.group_name   'groups/:urlname/',
                :controller => 'groups',
                :action => 'show'  
                

  map.connect   'users/:user_id/groups/new/edit',
                :controller => 'groups',
                :action => 'new',
                :requirements => { :user_id => /[0-9]*/}
                
  map.connect   'users/:user_id/groups/new/create',
                :controller => 'groups',
                :action => 'create',
                :requirements => { :user_id => /[0-9]*/}
                
  map.owned_groups   'users/:user_id/groups/list/',
                :controller => 'groups',
                :action => 'list',
                :requirements => { :user_id => /[0-9]*/}
  map.owned_groups   'users/:login/groups/list/',
                :controller => 'groups',
                :action => 'list'

  map.user_group   'users/:user_id/groups/:group_id',
                :controller => 'groups',
                :action => 'show',
                :requirements => { :user_id => /[0-9]*/, :group_id => /[0-9]*/}
  map.user_group   'users/:user_id/groups/:group_id/:action',
                :controller => 'groups',
                :requirements => { :user_id => /[0-9]*/, :group_id => /[0-9]*/}
  map.user_group   'users/:user_id/groups/:urlname',
                :controller => 'groups',
                :action => 'show',
                :requirements => { :user_id => /[0-9]*/}
  map.user_group   'users/:login/groups/:group_id',
                :controller => 'groups',
                :action => 'show',
                :requirements => { :group_id => /[0-9]*/}
  map.user_group   'users/:login/groups/:urlname',
                :controller => 'groups',
                :action => 'show'
  map.user_group   'users/:user_id/groups/:group_id/:action',
                :controller => 'groups',
                :requirements => { :user_id => /[0-9]*/, :group_id => /[0-9]*/ }


  # journal resources : both direct and delegated from the user
  map.journals  'journals',
                :controller => 'journals',
                :action => 'list'
                
  map.rss       'journals/rss',
                :controller => 'journals',
                :action => 'rss'

  map.connect   'journals/list',
                :controller => 'journals',
                :action => 'list'
                
  map.connect   'journals/:journal_id/show',
                :controller => 'journals',
                :action => 'show',
                :requirements => { :journal_id => /[0-9]*/}
  map.connect   'journals/:urlname/show',
                :controller => 'journals',
                :action => 'show'
  map.journal_id  'journals/:journal_id',
                :controller => 'journals',
                :action => 'show',
                :requirements => { :journal_id => /[0-9]*/}
  map.journal_name 'journals/:urlname/',
                :controller => 'journals',
                :action => 'show'  

  map.connect   'users/:user_id/journals/new/edit',
                :controller => 'journals',
                :action => 'new',
                :requirements => { :user_id => /[0-9]*/}
                
  map.connect   'users/:user_id/journals/new/create',
                :controller => 'journals',
                :action => 'create',
                :requirements => { :user_id => /[0-9]*/}
                
  map.user_journal   'users/:user_id/journals/:journal_id',
                :controller => 'journals',
                :action => 'show',
                :requirements => { :user_id => /[0-9]*/, :journal_id => /[0-9]*/}
  map.connect   'users/:user_id/journals/:journal_id/:action',
                :controller => 'journals',
                :requirements => { :user_id => /[0-9]*/, :journal_id => /[0-9]*/}
  map.connect   'users/:user_id/journals/:urlname',
                :controller => 'journals',
                :action => 'show',
                :requirements => { :user_id => /[0-9]*/}
  map.connect   'users/:login/journals/:journal_id',
                :controller => 'journals',
                :action => 'show',
                :requirements => { :journal_id => /[0-9]*/}
  map.connect   'users/:login/journals/:urlname',
                :controller => 'journals',
                :action => 'show',
                :requirements => { :user_id => /[0-9]*/}
  map.connect   'users/:user_id/journals/:journal_id/:action',
                :controller => 'journals',
                :requirements => { :user_id => /[0-9]*/, :journal_id => /[0-9]*/ }

                
  map.connect   'users/:user_id/:urlname/:year/:month',
                :controller => 'journals',
                :action => 'show',
                :month => nil,
                :requirements => { :user_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/ }
  map.connect   'users/:login/:journal_id/:year/:month',
                :controller => 'journals',
                :action => 'show',
                :month => nil,
                :requirements => { :journal_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/ }
  map.connect   'users/:login/:urlname/:year/:month',
                :controller => 'journals',
                :action => 'show',
                :month => nil,
                :requirements => { :year => /[0-9]{4}/, :month => /[0-9]{2}/ }

  map.connect   'users/:user_id/:journal_id/:year/:month',
                :controller => 'journals',
                :action => 'show',
                :month => nil,
                :requirements => { :user_id => /[0-9]*/, :journal_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/ }                

  # entry operations :
  map.connect   'users/:user_id/journals/:journal_id/:year/:month/:date',
                :controller => 'entries',
                :action => 'show',
                :requirements => { :user_id => /[0-9]*/, :journal_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
                
  map.connect   'users/:user_id/journals/:urlname/:year/:month/:date',
                :controller => 'entries',
                :action => 'show',
                :requirements => { :user_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
                
  map.connect   'users/:login/journals/:journal_id/:year/:month/:date',
                :controller => 'entries',
                :action => 'show',
                :requirements => { :journal_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
                
  map.connect   'users/:login/journals/:urlname/:year/:month/:date',
                :controller => 'entries',
                :action => 'show',
                :requirements => { :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
                
  map.connect   'users/:user_id/journals/:journal_id/:year/:month/:date/:action',
                :controller => 'entries',
                :requirements => { :journal_id => /[0-9]*/, :user_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
  map.connect   'users/:user_id/journals/:journal_id/:year/:month/:date/new/edit',
                :controller => 'entries',
                :action=> 'new',
                :requirements => { :journal_id => /[0-9]*/, :user_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
  map.connect   'users/:user_id/journals/:journal_id/:year/:month/:date/new/create',
                :controller => 'entries',
                :action=> 'create',
                :requirements => { :journal_id => /[0-9]*/, :user_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
  map.connect   'users/:user_id/journals/:urlname/:year/:month/:date/:action',
                :controller => 'entries',
                :requirements => { :user_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
  map.connect   'users/:login/journals/:journal_id/:year/:month/:date/:action',
                :controller => 'entries',
                :requirements => { :journal_id => /[0-9]*/,
                                   :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
  map.connect   'users/:login/journals/:urlname/:year/:month/:date/:action',
                :controller => 'entries',
                :requirements => { :year => /[0-9]{4}/, :month => /[0-9]{2}/, :date => /[0-9]{2}/ }
                
  # user resources :
  map.users     'users',
                :controller => 'users',
                :action => 'list'

  map.rss       'users/rss',
                :controller => 'users',
                :action => 'rss'

  map.user_id   'users/:user_id',
                :controller => 'users',
                :action => 'show',
                :requirements=> { :user_id => /[0-9]*/}
  map.user_operation   'users/:user_id/:action',
                :controller => 'users',
                :requirements=> { :user_id => /[0-9]*/}
  map.connect   'users/:login',
                :controller => 'users',
                :action => 'show'

  map.entry_photo 'images/users/:user_id/:action/:entry_id/:name/',
                :controller=> 'images',
                :requirements => { :action=> /photo/,
                                   :user_id => /[0-9]*/, :entry_id => /[0-9]*/ }

  map.entry_photo 'images/users/:user_id/:action/:entry_id/:size/:name/',
                :controller=> 'images',
                :requirements => { :action=> /photo/,
                                   :user_id => /[0-9]*/, :entry_id => /[0-9]*/ }

  map.user_avatar 'images/users/:user_id/:action/:name',
                :controller=> 'images',
                :requirements => { :action=> /avatar/,
                                   :user_id => /[0-9]*/ }

  map.public_image 'images/:filename',
                :controller=> 'images',
                :action=> 'public'

  # default dispatch
  map.connect   ':controller/:action/:id'
end
