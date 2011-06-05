
2006-11-19  james.anderson

here are a few notes about testing:

0. ensure that _all_ requisite fixtures are present. include those for related instances:
0.a like an entry's journals and user.
0.b like a user's roles - otherwise they have no permission

1. make sure that the test function establishes the complete request context.
this applies both for the "server" state and for the request proper.
1.a. login: use login_as(<login>) to establish the session state.
(see lib/authenticated_test_helper)
1.b. include user data in the request as required by the controller. for example
an admin id for destroy.

2. if there are relations, make sure they are refreshed before referencing them.
for example Groups#owner is initially nil.

3. ensure that fixtures and requests have complete data. failing that instance
validation may fail for creation operations.

...
