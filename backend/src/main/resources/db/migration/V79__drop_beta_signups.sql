-- The beta sign-up of the Apps page is gone: the apps are in their stores, and the testers of a
-- closed test now join through the store's own channel. V35's table has no reader left, and the
-- addresses it holds were only ever kept to announce a beta.

drop table beta_signups;
