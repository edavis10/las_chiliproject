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

require 'net/ldap'
require 'iconv'

# Ruby's timeout.rb isn't the best timeout an operation but since we
# are only using it on login (a blocking event), it's good enough.
require 'timeout'

class AuthSourceLdap < AuthSource 
  validates_presence_of :host, :port, :attr_login
  validates_length_of :name, :host, :maximum => 60, :allow_nil => true
  validates_length_of :account, :account_password, :base_dn, :maximum => 255, :allow_nil => true
  validates_length_of :attr_login, :attr_firstname, :attr_lastname, :attr_mail, :maximum => 30, :allow_nil => true
  validates_numericality_of :port, :only_integer => true

  before_validation :strip_ldap_attributes

  serialize :custom_attributes

  def after_initialize
    self.port = 389 if self.port == 0
    self.custom_attributes = {} if self.custom_attributes.nil?
    @failover = false
  end

  def authenticate(login, password)
    return nil if login.blank? || password.blank?

    Timeout::timeout(self.class.timeout_length, Net::LDAP::LdapError) {
      attrs = get_user_dn(login)

      if attrs && attrs[:dn] && authenticate_dn(attrs[:dn], password)
        logger.debug "Authentication successful for '#{login}'" if logger && logger.debug?
        return attrs.except(:dn)
      end

    }
  rescue  Net::LDAP::LdapError => text
    if allow_failover? && !failover_triggered?
      try_to_failover_and_log
      retry
    else
      raise "LdapError: " + text
    end
  end

  # test the connection to the LDAP
  def test_connection
    Timeout::timeout(self.class.timeout_length, Net::LDAP::LdapError) {
      ldap_con = initialize_ldap_con(self.account, self.account_password)
      ldap_con.open { }
    }
  rescue  Net::LDAP::LdapError => text
    if allow_failover? && !failover_triggered?
      try_to_failover_and_log
      retry
    else
      raise "LdapError: " + text
    end
  end

  def auth_method_name
    "LDAP"
  end

  # Skip the primary host until after this time
  def failover_until
    if options.present? && options[:failover_until].present?
      options[:failover_until]
    else
      nil
    end
  end

  # Is the server in a cached failover mode?
  def in_cached_failover?
    failover_until && Time.now <= failover_until
  end
  
  # Has an failover been triggered yet?
  def failover_triggered?
    @failover || in_cached_failover?
  end

  # Which host is currently being used
  def current_host
    if failover_triggered?
      self.failover_host
    else
      self.host
    end
  end

  def self.timeout_length
    10
  end

  # How many minutes should the failover be cached for
  def self.failover_cache_time
    20
  end
  
  private

  def strip_ldap_attributes
    [:attr_login, :attr_firstname, :attr_lastname, :attr_mail].each do |attr|
      write_attribute(attr, read_attribute(attr).strip) unless read_attribute(attr).nil?
    end
  end

  def initialize_ldap_con(ldap_user, ldap_password)
    options = { :host => current_host,
                :port => self.port,
                :encryption => (self.tls ? :simple_tls : nil)
              }
    options.merge!(:auth => { :method => :simple, :username => ldap_user, :password => ldap_password }) unless ldap_user.blank? && ldap_password.blank?
    Net::LDAP.new options
  end

  def get_user_attributes_from_ldap_entry(entry)
    custom_field_values = {}
    custom_attributes.each do |custom_field_id, ldap_attr_name|
      custom_field_values[custom_field_id] = AuthSourceLdap.get_attr(entry, ldap_attr_name)
    end

    {
     :dn => entry.dn,
     :firstname => AuthSourceLdap.get_attr(entry, self.attr_firstname),
     :lastname => AuthSourceLdap.get_attr(entry, self.attr_lastname),
     :mail => AuthSourceLdap.get_attr(entry, self.attr_mail),
     :auth_source_id => self.id,
     :custom_field_values => custom_field_values
    }
  end

  # Return the attributes needed for the LDAP search.  It will only
  # include the user attributes if on-the-fly registration is enabled
  def search_attributes
    if onthefly_register?
      ['dn', self.attr_firstname, self.attr_lastname, self.attr_mail] + custom_attributes.values
    else
      ['dn']
    end
  end

  # Check if a DN (user record) authenticates with the password
  def authenticate_dn(dn, password)
    if dn.present? && password.present?
      initialize_ldap_con(dn, password).bind
    end
  end

  # Get the user's dn and any attributes for them, given their login
  def get_user_dn(login)
    ldap_con = initialize_ldap_con(self.account, self.account_password)
    login_filter = Net::LDAP::Filter.eq( self.attr_login, login ) 
    object_filter = Net::LDAP::Filter.eq( "objectClass", "*" )
    custom_ldap_filter = custom_filter_to_ldap

    if custom_ldap_filter.present?
      search_filters = object_filter & login_filter & custom_ldap_filter
    else
      search_filters = object_filter & login_filter
    end
    attrs = {}
    
    ldap_con.search( :base => self.base_dn, 
                     :filter => search_filters, 
                     :attributes=> search_attributes) do |entry|

      if onthefly_register?
        attrs = get_user_attributes_from_ldap_entry(entry)
      else
        attrs = {:dn => entry.dn}
      end

      logger.debug "DN found for #{login}: #{attrs[:dn]}" if logger && logger.debug?
    end

    attrs
  end

  def custom_filter_to_ldap
    return nil unless custom_filter.present?
    
    begin
      return Net::LDAP::Filter.construct(custom_filter)
    rescue Net::LDAP::LdapError # Filter syntax error
      logger.debug "LDAP custom filter syntax error for: #{custom_filter}" if logger && logger.debug?
      return nil
    end
  end
  
  def allow_failover?
    failover_host.present?
  end
  
  # Mark the main server as failed
  def failover!
    @failover = true
    self.options ||= {}
    self.options[:failover_until] = 20.minutes.from_now
    save
  end

  def try_to_failover_and_log
    logger.debug "AuthSourceLdap: LDAP server #{self.host} is not responding, failing over to #{self.failover_host}"
    failover!
  end
  
  def self.get_attr(entry, attr_name)
    if !attr_name.blank?
      entry[attr_name].is_a?(Array) ? entry[attr_name].first : entry[attr_name]
    end
  end
end
