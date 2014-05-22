#
# Cookbook Name:: s3nsync
# Resource:: default
#

actions :create, :delete

attribute :name, :kind_of => String, :name_attribute => true
attribute :bucket, :kind_of => [String]
attribute :region, :kind_of => [String], default => 'us-east-1'

attr_accessor :exists

def initialize(*args)
    super
    @action = :create
end
