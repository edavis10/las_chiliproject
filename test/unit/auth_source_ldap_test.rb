#-- copyright
# ChiliProject is a project management system.
#
# Copyright (C) 2010-2011 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# See doc/COPYRIGHT.rdoc for more details.
#++
require File.expand_path('../../test_helper', __FILE__)

class AuthSourceLdapTest < ActiveSupport::TestCase
  fixtures :auth_sources

  def setup
  end

  def test_create
    a = AuthSourceLdap.new(:name => 'My LDAP', :host => 'ldap.example.net', :port => 389, :base_dn => 'dc=example,dc=net', :attr_login => 'sAMAccountName')
    assert a.save
  end

  def test_should_strip_ldap_attributes
    a = AuthSourceLdap.new(:name => 'My LDAP', :host => 'ldap.example.net', :port => 389, :base_dn => 'dc=example,dc=net', :attr_login => 'sAMAccountName',
                           :attr_firstname => 'givenName ')
    assert a.save
    assert_equal 'givenName', a.reload.attr_firstname
  end

  should_have_and_belong_to_many :groups

  if ldap_configured?
    context '#authenticate' do
      setup do
        @custom_field = UserCustomField.generate!(:name => 'Home directory')

        @auth = AuthSourceLdap.find(1)
        @auth.custom_attributes = {@custom_field.id.to_s => 'homeDirectory'}
        @auth.save!

      end

      context 'with a valid LDAP user' do
        should 'return the user attributes' do
          attributes =  @auth.authenticate('example1','123456')
          assert attributes.is_a?(Hash), "An hash was not returned"
          assert_equal 'Example', attributes[:firstname]
          assert_equal 'One', attributes[:lastname]
          assert_equal 'example1@redmine.org', attributes[:mail]
          assert_equal @auth.id, attributes[:auth_source_id]
          attributes.keys.each do |attribute|
            assert User.new.respond_to?("#{attribute}="), "Unexpected :#{attribute} attribute returned"
          end
        end

        should 'return custom field attributes from LDAP xxx' do
          attributes = @auth.authenticate('example1','123456')

          assert attributes.is_a?(Hash), "A hash was not returned"

          custom_field_attributes = attributes[:custom_field_values]
          assert custom_field_attributes.is_a?(Hash)
          assert custom_field_attributes.include?(@custom_field.id.to_s), "Custom field wasn't returned"
          assert_equal "/home/example1", custom_field_attributes[@custom_field.id.to_s]
        end
      end

      context 'with an invalid LDAP user' do
        should 'return nil' do
          assert_equal nil, @auth.authenticate('nouser','123456')
        end
      end

      context 'without a login' do
        should 'return nil' do
          assert_equal nil, @auth.authenticate('','123456')
        end
      end

      context 'without a password' do
        should 'return nil' do
          assert_equal nil, @auth.authenticate('edavis','')
        end
      end

      context "using a valid custom filter" do
        setup do
          @auth.update_attributes(:custom_filter => "(& (homeDirectory=*) (sn=O*))")
        end

        should "find a user who authenticates and matches the custom filter" do
          assert_not_nil @auth.authenticate('example1', '123456')
        end

        should "be nil for users who don't match the custom filter" do
          assert_nil @auth.authenticate('edavis', '123456')
        end
      end

      context "using an invalid custom filter" do
        setup do
          # missing )) at the end
          @auth.update_attributes(:custom_filter => "(& (homeDirectory=*) (sn=O*")
        end

        should "skip the custom filter" do
          assert_not_nil @auth.authenticate('example1', '123456')
          assert_not_nil @auth.authenticate('edavis', '123456')
        end
      end

    end

    context "failover" do
      setup do
        @auth = AuthSourceLdap.find(1)
        @auth.failover_host = '127.0.0.1'
        @auth.host = '127.0.0.0' # unroutable and returns fast
        @auth.save!
        @auth.reload
      end
      
      should "connect to the failover host if the main one doesn't respond" do
        assert_nothing_raised do
          @auth.test_connection
        end
      end

      should "work on authentication" do
        assert_nothing_raised do
          @auth.authenticate('example1','123456')
        end
      end
      
    end

    context "failover cache" do
      setup do
        @auth = AuthSourceLdap.find(1)
        @auth.failover_host = '127.0.0.1'
        @auth.host = '127.0.0.0' # unroutable and returns fast
        @auth.save!
        @auth.reload
      end
      
      should "cache when a server hit failover for 20 minutes" do
        failed_time = Time.now
        @auth.test_connection
        
        @auth.reload

        assert @auth.failover_until.present?, "Failover not cached"
        # Roughly within 20-22 minutes form now
        assert @auth.failover_until >= failed_time + 20.minutes
        assert @auth.failover_until < failed_time + 22.minutes
      end
      
      should "skip the primary LDAP server until the cache is cleared" do
        @auth.send('failover!') # Trigger the failover
        @auth = AuthSourceLdap.find(@auth.id)

        assert @auth.failover_triggered?
        assert_equal "127.0.0.1", @auth.current_host
      end
      
      should "retry the primary server after the cache is cleared" do
        @auth.options ||= {}
        @auth.options[:failover_until] = 1.minute.ago
        @auth.save
        @auth = AuthSourceLdap.find(@auth.id)

        assert !@auth.failover_triggered?
        assert_equal "127.0.0.0", @auth.current_host
      end

    end
    
  else
    puts '(Test LDAP server not configured)'
  end
end
