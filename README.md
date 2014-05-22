s3nsync Cookbook
=======================
This cookbook probides a LWRP that keeps a local directory synced to an S3 bucket. It does an initial sync from an S3 bucket to a local directory (if it's empty), and then syncs that directory with a folder in that S3 bucket each Chef run. This is an easy way to back a recent backup copy of data in S3 and have new nodes grab it when they are launched.

Requirements
------------
This cookbook does not depend on any other cookbooks. It requires that the [AWS CLI tool](https://aws.amazon.com/cli/) is installed.

Usage
-----
#### s3nsync resource

```
s3nsync "/var/lib/git-repos" do
    bucket "s3-sync-bucket"
    region "us-east-1"
    action :create
end
```
This example would keep a local /var/lib/git-repos directory synced to a folder in the "s3-sync-bucket" S3 bucket.

The name of the resource is the directory to keep in sync with the S3 bucket. You need to specify a `bucket`. The default `region` is 'us-east-1'. The default and only action is create.

The first time this runs, if the directory is empty, the recipe will look for a "CURRENT" file in the specified S3 bucket. This file should contain the path within the S3 bucket of the current folder to sync locally. It will sync the contents of that folder locally, then create an /etc/chef/.initial_s3_sync_<bucket> file so that this initial sync only happens once. If the local directory was not empty to begin with, it will not do an initial sync and will require you to create this .initial_s3_sync_<bucket> file manually (for safety).

If the initial sync has previously completed successfully, then the only action upon a chef-client run will be to sync the local directory to the S3 bucket into a subfolder named with the node.name attribute. This way if a new instance is brought up, it will not accidentally overwrite files from a previous instance. If an instance successfully syncs to S3, the CURRENT file will be updated with it's foldername. This allows a simple way to keep a very recent backup in S3 and have new instances grab a copy of this data when they are launched and start syncing to S3 themselved.

Additionally, an init script and service will be configured which does a final sync on shutdown or reboot, such as when an instance is terminated.

Contributing
------------
1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------
Authors: Joe Richards <nospam-github@disconformity.net>
