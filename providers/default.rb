#
# Cookbook Name:: s3nsync
# Provider:: default
#

use_inline_resources

def whyrun_supported?
    true
end

action :create do
    require 'fileutils'

    region     = new_resource.region
    bucket     = new_resource.bucket
    sync_path  = new_resource.name

    case node['platform']
        when 'debian','ubuntu'
            command_prefix = "/usr/local/bin/"
        when 'redhat','centos','fedora','amazon','scientific'
            command_prefix = "/usr/bin/"
    end

    command_awscli_s3 = "#{command_prefix}aws --region #{region} s3"

    unless @current_resource.exists
        current = ""
        converge_by("Checking S3 bucket s3://#{bucket}") do
            command     = "#{command_awscli_s3} mb s3://#{bucket} || true"
            log_message = "Creating bucket if it doesn't exist"
            cli_check(cli_run(command, log_message), command)

            command     = "#{command_awscli_s3} cp s3://#{bucket}/CURRENT /etc/chef/.#{bucket}_CURRENT"
            log_message = "Checking for current sync folder..."
            shell = cli_run(command, log_message)
            if shell.stdout.include?('Key "CURRENT" does not exist')
                Chef::Log.info("No current folder set. Setting to self.")
                ::File.open("/etc/chef/.#{bucket}_CURRENT", "w") { |f| f.write(node.name) }
            else
                cli_check(shell, command)
            end

            if ::File.exist?("/etc/chef/.#{bucket}_CURRENT")
                current = ::File.open("/etc/chef/.#{bucket}_CURRENT", 'rb') { |f| f.read }.strip
                Chef::Log.info("Current S3 sync folder: #{current}")
            else
                Chef::Log.fatal "CURRENT not found!"
                raise "Could not open /etc/chef/.#{bucket}_CURRENT:" + shell.stdout
            end

            FileUtils.mkdir_p sync_path
        end
        unless ::File.exist?("/etc/chef/.initial_s3_sync_#{bucket}")
            converge_by("Initial sync from s3://#{bucket} to #{sync_path}") do
                if Dir["#{sync_path}/*"].empty?
                    command     = "#{command_awscli_s3} sync s3://#{bucket}/#{current} #{sync_path}"
                    log_message = "Starting initial sync of S3 bucket s3://#{bucket}/#{current} to#{sync_path}"
                    cli_check(cli_run(command, log_message), command)

                    Chef::Log.info("Initial sync complete.")
                    ::File.open("/etc/chef/.initial_s3_sync_#{bucket}", "w") {}
                else
                    Chef::Log.warn("Skipping initial sync, #{sync_path} is not empty.
                        Manually touch the file /etc/chef/.initial_s3_sync_#{bucket} or remove contents of directory.")
                end
            end
        end
    end
    unless ::File.exist?("/etc/init.d/s3_sync_#{bucket}")
        converge_by("Adding final sync script for system shutdown") do
            init = "#/bin/bash\n\n"
            init << "# chkconfig: 06 1 1\n"
            init << "# description: Sync path to S3 bucket\n"
            init << "echo 'Syncing #{sync_path} to S3 bucket #{bucket}...'\n"
            init << "#{command_awscli_s3} sync #{sync_path} s3://#{bucket}/#{node.name} --delete\n"
            ::File.open("/etc/init.d/s3_sync_#{bucket}", "w", 0755) { |f| f.write(init) }
        end
    end
    service "s3_sync_#{bucket}" do
        action [:enable]
    end
    converge_by("Syncing from #{sync_path} to s3://#{bucket}/#{node.name} ") do
        command     = "#{command_awscli_s3} sync #{sync_path} s3://#{bucket}/#{node.name} --delete"
        log_message = "Syncing #{sync_path} to S3 bucket s3://#{bucket}/#{node.name}"
        cli_check(cli_run(command, log_message), command)
    end
    converge_by("Updating current S3 sync folder") do
        ::File.open("/tmp/CURRENT", "w") { |f| f.write(node.name) }

        command     = "#{command_awscli_s3} cp /tmp/CURRENT s3://#{bucket}/CURRENT"
        log_message = "Setting CURRENT to s3://#{bucket}/#{node.name}"
        cli_check(cli_run(command, log_message), command)
    end
    Chef::Log.info('Syncing complete. Bye bye bye.')
    @new_resource.updated_by_last_action(true)
end

action :delete do
end

def load_current_resource
    @current_resource = Chef::Resource::S3nsync.new(@new_resource.name)
    if ::File.exist?("/etc/chef/.intial_s3_sync_#{new_resource.bucket}")
        Chef::Log.info("Already did initial sync.")
        initial_sync = true
    end
    if ::File.exist?("/etc/chef/.#{new_resource.bucket}_CURRENT")
        Chef::Log.info("Already set to current.")
        bucket_current = true
    end
    if initial_sync && bucket_current
        Chef::Log.info("Resource already exists.")
        @current_resource.exists = true
    end
end

def cli_run(command, log_message)
    Chef::Log.info(log_message)
    shell = Mixlib::ShellOut.new("#{command} 2>&1")
    shell.run_command
end

def cli_check(shell, command)
    if !shell.exitstatus || shell.exitstatus != 0
        Chef::Log.fatal("\n#{shell.stdout}")
        raise "#{command} failed:" + shell.stdout
    end
    Chef::Log.debug("\n#{shell.stdout}")
end
