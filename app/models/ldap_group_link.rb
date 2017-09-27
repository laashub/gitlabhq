class LdapGroupLink < ActiveRecord::Base
  include Gitlab::Access
  belongs_to :group

  BLANK_ATTRIBUTES = %w[cn filter].freeze

  with_options if: :cn do |link|
    link.validates :cn, :group_access, :group_id, presence: true, unless: :filter
    link.validates :cn, uniqueness: { scope: [:group_id, :provider] }, if: :cn
    link.validates :filter, absence: true
  end

  with_options if: :filter do |link|
    link.validates :filter, :group_access, :group_id, presence: true
    link.validates :filter, uniqueness: { scope: [:group_id, :provider] }
    link.validates :filter, ldap_filter: true
    link.validates :cn, absence: true
  end

  validates :group_access, inclusion: { in: Gitlab::Access.all_values }
  validates :provider, presence: true

  scope :with_provider, ->(provider) { where(provider: provider) }

  before_validation :nullify_blank_attributes

  def access_field
    group_access
  end

  def config
    Gitlab::LDAP::Config.new(provider)
  rescue Gitlab::LDAP::Config::InvalidProvider
    nil
  end

  # default to the first LDAP server
  def provider
    read_attribute(:provider) || Gitlab::LDAP::Config.providers.first
  end

  def provider_label
    config.label
  end

  private

  def nullify_blank_attributes
    BLANK_ATTRIBUTES.each { |attr| self[attr] = nil if self[attr].blank? }
  end
end
