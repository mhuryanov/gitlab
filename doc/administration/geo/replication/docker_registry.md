---
stage: Enablement
group: Geo
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: howto
---

# Docker Registry for a secondary site **(PREMIUM SELF)**

You can set up a [Docker Registry](https://docs.docker.com/registry/) on your
**secondary** Geo site that mirrors the one on the **primary** Geo site.

## Storage support

Docker Registry currently supports a few types of storage. If you choose a
distributed storage (`azure`, `gcs`, `s3`, `swift`, or `oss`) for your Docker
Registry on the **primary** site, you can use the same storage for a **secondary**
Docker Registry as well. For more information, read the
[Load balancing considerations](https://docs.docker.com/registry/deploying/#load-balancing-considerations)
when deploying the Registry, and how to set up the storage driver for the GitLab
integrated [Container Registry](../../packages/container_registry.md#use-object-storage).

## Replicating Docker Registry

You can enable a storage-agnostic replication so it
can be used for cloud or local storage. Whenever a new image is pushed to the
**primary** site, each **secondary** site will pull it to its own container
repository.

To configure Docker Registry replication:

1. Configure the [**primary** site](#configure-primary-site).
1. Configure the [**secondary** site](#configure-secondary-site).
1. Verify Docker Registry [replication](#verify-replication).

### Configure **primary** site

Make sure that you have Container Registry set up and working on
the **primary** site before following the next steps.

We need to make Docker Registry send notification events to the
**primary** site.

1. SSH into your GitLab **primary** server and login as root:

   ```shell
   sudo -i
   ```

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   registry['notifications'] = [
     {
       'name' => 'geo_event',
       'url' => 'https://example.com/api/v4/container_registry_event/events',
       'timeout' => '500ms',
       'threshold' => 5,
       'backoff' => '1s',
       'headers' => {
         'Authorization' => ['<replace_with_a_secret_token>']
       }
     }
   ]
   ```

   NOTE:
   Replace `<replace_with_a_secret_token>` with a case sensitive alphanumeric string
   that starts with a letter. You can generate one with `< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 32 | sed "s/^[0-9]*//"; echo`

   NOTE:
   If you use an external Registry (not the one integrated with GitLab), you must add
   these settings to its configuration yourself. In this case, you will also have to specify
   notification secret in `registry.notification_secret` section of
   `/etc/gitlab/gitlab.rb` file.

   NOTE:
   If you use GitLab HA, you will also have to specify
   the notification secret in `registry.notification_secret` section of
   `/etc/gitlab/gitlab.rb` file for every web node.

1. Reconfigure the **primary** node for the change to take effect:

   ```shell
   gitlab-ctl reconfigure
   ```

### Configure **secondary** site

Make sure you have Container Registry set up and working on
the **secondary** site before following the next steps.

The following steps should be done on each **secondary** site you're
expecting to see the Docker images replicated.

Because we need to allow the **secondary** site to communicate securely with
the **primary** site Container Registry, we need to have a single key
pair for all the sites. The **secondary** site will use this key to
generate a short-lived JWT that is pull-only-capable to access the
**primary** site Container Registry.

For each application node on the **secondary** site: 

1. SSH into the node and login as the `root` user:

   ```shell
   sudo -i
   ```

1. Copy `/var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key` from the **primary** to the node.

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['geo_registry_replication_enabled'] = true
   gitlab_rails['geo_registry_replication_primary_api_url'] = 'https://primary.example.com:5050/' # Primary registry address, it will be used by the secondary node to directly communicate to primary registry
   ```

1. Reconfigure the node for the change to take effect:

   ```shell
   gitlab-ctl reconfigure
   ```

### Verify replication

To verify Container Registry replication is working, go to **Admin Area > Geo**
(`/admin/geo/nodes`) on the **secondary** site.
The initial replication, or "backfill", will probably still be in progress.
You can monitor the synchronization process on each Geo site from the **primary** site's **Geo Nodes** dashboard in your browser.
