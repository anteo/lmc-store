LMC (LocalMemCache) store
------------------

[lmc_store](http://github.com/anteo/lmc_store) is an ActiveSupport::Cache::Store implementation for
[LocalMemCache](http://localmemcache.rubyforge.org/) in Rails.

## Disclaimer

This gem was created because there are no other gems for modern Rails >= 6.
While it is in alpha stage, use it at your own risk.

## Installation

Add this line to your application's Gemfile:

    gem 'lmc_store'

And then execute:

    $ bundle

If using Rails, in `config/application.rb`:

    config.cache_store = :lmc_store

Done!