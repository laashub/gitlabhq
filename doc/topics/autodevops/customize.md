# Customizing Auto DevOps

While Auto DevOps provides great defaults to get you started, you can customize
almost everything to fit your needs; from custom [buildpacks](#custom-buildpacks),
to [`Dockerfile`s](#custom-dockerfile), [Helm charts](#custom-helm-chart), or
even copying the complete [CI/CD configuration](#customizing-gitlab-ciyml)
into your project to enable staging and canary deployments, and more.

## Custom buildpacks

If the automatic buildpack detection fails for your project, or if you want to
use a custom buildpack, you can override the buildpack(s) using a project variable
or a `.buildpacks` file in your project:

- **Project variable** - Create a project variable `BUILDPACK_URL` with the URL
  of the buildpack to use.
- **`.buildpacks` file** - Add a file in your project's repo called  `.buildpacks`
  and add the URL of the buildpack to use on a line in the file. If you want to
  use multiple buildpacks, you can enter them in, one on each line.

The buildpack URL can point to either a Git repository URL or a tarball URL.
For Git repositories, it is possible to point to a specific Git reference (for example,
commit SHA, tag name, or branch name) by appending `#<ref>` to the Git repository URL.
For example:

- The tag `v142`: `https://github.com/heroku/heroku-buildpack-ruby.git#v142`.
- The branch `mybranch`: `https://github.com/heroku/heroku-buildpack-ruby.git#mybranch`.
- The commit SHA `f97d8a8ab49`: `https://github.com/heroku/heroku-buildpack-ruby.git#f97d8a8ab49`.

### Multiple buildpacks

Using multiple buildpacks isn't fully supported by Auto DevOps because, when using the `.buildpacks`
file, Auto Test will not work.

The buildpack [heroku-buildpack-multi](https://github.com/heroku/heroku-buildpack-multi/),
which is used under the hood to parse the `.buildpacks` file, doesn't provide the necessary commands
`bin/test-compile` and `bin/test`.

If your goal is to use only a single custom buildpack, you should provide the project variable
`BUILDPACK_URL` instead.

## Custom `Dockerfile`

If your project has a `Dockerfile` in the root of the project repo, Auto DevOps
will build a Docker image based on the Dockerfile rather than using buildpacks.
This can be much faster and result in smaller images, especially if your
Dockerfile is based on [Alpine](https://hub.docker.com/_/alpine/).

## Passing arguments to `docker build`

Arguments can be passed to the `docker build` command using the
`AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` project variable.

For example, to build a Docker image based on based on the `ruby:alpine`
instead of the default `ruby:latest`:

1. Set `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS` to `--build-arg=RUBY_VERSION=alpine`.
1. Add the following to a custom `Dockerfile`:

   ```dockerfile
   ARG RUBY_VERSION=latest
   FROM ruby:$RUBY_VERSION

   # ... put your stuff here
   ```

NOTE: **Note:**
Passing in complex values (newlines and spaces, for example) will likely
cause escaping issues due to the way this argument is used in Auto DevOps.
Consider using Base64 encoding of such values to avoid this problem.

CAUTION: **Warning:**
Avoid passing secrets as Docker build arguments if possible, as they may be
persisted in your image. See
[this discussion](https://github.com/moby/moby/issues/13490) for details.

## Passing secrets to `docker build`

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/25514) in GitLab 12.3, but available in versions 11.9 and above.

CI environment variables can be passed as [build
secrets](https://docs.docker.com/develop/develop-images/build_enhancements/#new-docker-build-secret-information) to the `docker build` command by listing them comma separated by name in the
`AUTO_DEVOPS_BUILD_IMAGE_FORWARDED_CI_VARIABLES` variable. For example, in order to forward the variables `CI_COMMIT_SHA` and `CI_ENVIRONMENT_NAME`, one would set `AUTO_DEVOPS_BUILD_IMAGE_FORWARDED_CI_VARIABLES` to `CI_COMMIT_SHA,CI_ENVIRONMENT_NAME`.

Unlike build arguments, these are not persisted by Docker in the final image
(though you can still persist them yourself, so **be careful**).

In projects:

- Without a `Dockerfile`, these are available automatically as environment
  variables.
- With a `Dockerfile`, the following is required:

  1. Activate the experimental `Dockerfile` syntax by adding the following
     to the top of the file:

     ```dockerfile
     # syntax = docker/dockerfile:experimental
     ```

  1. To make secrets available in any `RUN $COMMAND` in the `Dockerfile`, mount
     the secret file and source it prior to running `$COMMAND`:

     ```dockerfile
     RUN --mount=type=secret,id=auto-devops-build-secrets . /run/secrets/auto-devops-build-secrets && $COMMAND
     ```

NOTE: **Note:**
When `AUTO_DEVOPS_BUILD_IMAGE_FORWARDED_CI_VARIABLES` is set, Auto DevOps
enables the experimental [Docker BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/)
feature to use the `--secret` flag.

## Custom Helm Chart

Auto DevOps uses [Helm](https://helm.sh/) to deploy your application to Kubernetes.
You can override the Helm chart used by bundling up a chart into your project
repo or by specifying a project variable:

- **Bundled chart** - If your project has a `./chart` directory with a `Chart.yaml`
  file in it, Auto DevOps will detect the chart and use it instead of the [default
  one](https://gitlab.com/gitlab-org/charts/auto-deploy-app).
  This can be a great way to control exactly how your application is deployed.
- **Project variable** - Create a [project variable](../../ci/variables/README.md#gitlab-cicd-environment-variables)
  `AUTO_DEVOPS_CHART` with the URL of a custom chart to use or create two project variables `AUTO_DEVOPS_CHART_REPOSITORY` with the URL of a custom chart repository and `AUTO_DEVOPS_CHART` with the path to the chart.

## Customize values for Helm Chart

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/30628) in GitLab 12.6, `.gitlab/auto-deploy-values.yaml` will be used by default for Helm upgrades.

You can override the default values in the `values.yaml` file in the [default Helm chart](https://gitlab.com/gitlab-org/charts/auto-deploy-app).
This can be achieved by either:

- Adding a file named `.gitlab/auto-deploy-values.yaml` to your repository. It will
  be automatically used if found.
- Adding a file with a different name or path to the repository, and set the
  `HELM_UPGRADE_VALUES_FILE` [environment variable](#environment-variables) with the path and name.

NOTE: **Note:**
For GitLab 12.5 and earlier, the `HELM_UPGRADE_EXTRA_ARGS` environment variable can be used to override the default chart values.
To do so, set `HELM_UPGRADE_EXTRA_ARGS` to `--values my-values.yaml`.

## Custom Helm chart per environment

You can specify the use of a custom Helm chart per environment by scoping the environment variable
to the desired environment. See [Limiting environment scopes of variables](../../ci/variables/README.md#limiting-environment-scopes-of-environment-variables).

## Customizing `.gitlab-ci.yml`

Auto DevOps is completely customizable because the [Auto DevOps template](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Auto-DevOps.gitlab-ci.yml):

- Is just an implementation of a [`.gitlab-ci.yml`](../../ci/yaml/README.md) file.
- Uses only features available to any implementation of `.gitlab-ci.yml`.

If you want to modify the CI/CD pipeline used by Auto DevOps, you can [`include`
the template](../../ci/yaml/README.md#includetemplate) and customize as
needed. To do this, add a `.gitlab-ci.yml` file to the root of your repository
containing the following:

```yml
include:
  - template: Auto-DevOps.gitlab-ci.yml
```

Then add any extra changes you want. Your additions will be merged with the
[Auto DevOps template](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Auto-DevOps.gitlab-ci.yml) using the behaviour described for
[`include`](../../ci/yaml/README.md#include).

It is also possible to copy and paste the contents of the [Auto DevOps template](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Auto-DevOps.gitlab-ci.yml)
into your project and edit this as needed. You may prefer to do it
that way if you want to specifically remove any part of it.

## Customizing the Kubernetes namespace

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/27630) in GitLab 12.6.

For **non**-GitLab-managed clusters, the namespace can be customized using
`.gitlab-ci.yml` by specifying
[`environment:kubernetes:namespace`](../../ci/environments.md#configuring-kubernetes-deployments).
For example, the following configuration overrides the namespace used for
`production` deployments:

```yaml
include:
  - template: Auto-DevOps.gitlab-ci.yml

production:
  environment:
    kubernetes:
      namespace: production
```

When deploying to a custom namespace with Auto DevOps, the service account
provided with the cluster needs at least the `edit` role within the namespace.

- If the service account can create namespaces, then the namespace can be created on-demand.
- Otherwise, the namespace must exist prior to deployment.

## Using components of Auto DevOps

If you only require a subset of the features offered by Auto DevOps, you can include
individual Auto DevOps jobs into your own `.gitlab-ci.yml`. Each component job relies
on a stage that should be defined in the `.gitlab-ci.yml` that includes the template.

For example, to make use of [Auto Build](stages.md#auto-build), you can add the following to
your `.gitlab-ci.yml`:

```yaml
stages:
  - build

include:
  - template: Jobs/Build.gitlab-ci.yml
```

Consult the [Auto DevOps template](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Auto-DevOps.gitlab-ci.yml) for information on available jobs.

## PostgreSQL database support

In order to support applications that require a database,
[PostgreSQL](https://www.postgresql.org/) is provisioned by default. The credentials to access
the database are preconfigured, but can be customized by setting the associated
[variables](#environment-variables). These credentials can be used for defining a
`DATABASE_URL` of the format:

```yaml
postgres://user:password@postgres-host:postgres-port/postgres-database
```

### Upgrading PostgresSQL

CAUTION: **Deprecation**
The variable `AUTO_DEVOPS_POSTGRES_CHANNEL` that controls default provisioned
PostgreSQL currently defaults to `1`. This is scheduled to change to `2` in
[GitLab 13.0](https://gitlab.com/gitlab-org/gitlab/-/issues/210499).

The version of the chart used to provision PostgreSQL:

- Is 0.7.1 in GitLab 12.8 and earlier.
- Can be set to from 0.7.1 to 8.2.1 in GitLab 12.9 and later.

GitLab encourages users to [migrate their database](upgrading_postgresql.md)
to the newer PostgreSQL.

To use the new PostgreSQL:

- New projects can set the `AUTO_DEVOPS_POSTGRES_CHANNEL` variable to `2`.
- Old projects can be upgraded by following the guide to
  [upgrading PostgresSQL](upgrading_postgresql.md).

### Using external PostgreSQL database providers

While Auto DevOps provides out-of-the-box support for a PostgreSQL container for
production environments, for some use-cases it may not be sufficiently secure or
resilient and you may wish to use an external managed provider for PostgreSQL.
For example, AWS Relational Database Service.

You will need to define environment-scoped variables for `POSTGRES_ENABLED` and `DATABASE_URL` in your project's CI/CD settings.

To achieve this:

1. Disable the built-in PostgreSQL installation for the required environments using
   scoped [environment variables](../../ci/environments.md#scoping-environments-with-specs).
   For this use case, it's likely that only `production` will need to be added to this
   list as the builtin PostgreSQL setup for Review Apps and staging will be sufficient
   as a high availability setup is not required.

   ![Auto Metrics](img/disable_postgres.png)

1. Define the `DATABASE_URL` CI variable as a scoped environment variable that will be
   available to your application. This should be a URL in the following format:

   ```yaml
   postgres://user:password@postgres-host:postgres-port/postgres-database
   ```

You will need to ensure that your Kubernetes cluster has network access to wherever
PostgreSQL is hosted.

## Environment variables

The following variables can be used for setting up the Auto DevOps domain,
providing a custom Helm chart, or scaling your application. PostgreSQL can
also be customized, and you can easily use a [custom buildpack](#custom-buildpacks).

### Build and deployment

The following table lists variables related to building and deploying
applications.

| **Variable**                            | **Description**                    |
|-----------------------------------------|------------------------------------|
| `ADDITIONAL_HOSTS`                      | Fully qualified domain names specified as a comma-separated list that are added to the Ingress hosts. |
| `<ENVIRONMENT>_ADDITIONAL_HOSTS`        | For a specific environment, the fully qualified domain names specified as a comma-separated list that are added to the Ingress hosts. This takes precedence over `ADDITIONAL_HOSTS`. |
| `AUTO_DEVOPS_BUILD_IMAGE_CNB_ENABLED`   | When set to a non-empty value and no `Dockerfile` is present, Auto Build builds your application using Cloud Native Buildpacks instead of Herokuish. [More details](stages.md#auto-build-using-cloud-native-buildpacks-beta). |
| `AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS`    | Extra arguments to be passed to the `docker build` command. Note that using quotes will not prevent word splitting. [More details](#passing-arguments-to-docker-build). |
| `AUTO_DEVOPS_BUILD_IMAGE_FORWARDED_CI_VARIABLES` | A [comma-separated list of CI variable names](#passing-secrets-to-docker-build) to be passed to the `docker build` command as secrets. |
| `AUTO_DEVOPS_CHART`                     | Helm Chart used to deploy your apps. Defaults to the one [provided by GitLab](https://gitlab.com/gitlab-org/charts/auto-deploy-app). |
| `AUTO_DEVOPS_CHART_REPOSITORY`          | Helm Chart repository used to search for charts. Defaults to `https://charts.gitlab.io`. |
| `AUTO_DEVOPS_CHART_REPOSITORY_NAME`     | From GitLab 11.11, used to set the name of the Helm repository. Defaults to `gitlab`. |
| `AUTO_DEVOPS_CHART_REPOSITORY_USERNAME` | From GitLab 11.11, used to set a username to connect to the Helm repository. Defaults to no credentials. Also set `AUTO_DEVOPS_CHART_REPOSITORY_PASSWORD`. |
| `AUTO_DEVOPS_CHART_REPOSITORY_PASSWORD` | From GitLab 11.11, used to set a password to connect to the Helm repository. Defaults to no credentials. Also set `AUTO_DEVOPS_CHART_REPOSITORY_USERNAME`. |
| `AUTO_DEVOPS_MODSECURITY_SEC_RULE_ENGINE` | From GitLab 12.5, used in combination with [Modsecurity feature flag](../../user/clusters/applications.md#web-application-firewall-modsecurity) to toggle [Modsecurity's `SecRuleEngine`](https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual-(v2.x)#SecRuleEngine) behavior. Defaults to `DetectionOnly`. |
| `BUILDPACK_URL`                         | Buildpack's full URL. Can point to either [a Git repository URL or a tarball URL](#custom-buildpacks). |
| `CANARY_ENABLED`                        | From GitLab 11.0, used to define a [deploy policy for canary environments](#deploy-policy-for-canary-environments-premium). |
| `CANARY_PRODUCTION_REPLICAS`            | Number of canary replicas to deploy for [Canary Deployments](../../user/project/canary_deployments.md) in the production environment. Takes precedence over `CANARY_REPLICAS`. Defaults to 1. |
| `CANARY_REPLICAS`                       | Number of canary replicas to deploy for [Canary Deployments](../../user/project/canary_deployments.md). Defaults to 1. |
| `HELM_RELEASE_NAME`                     | From GitLab 12.1, allows the `helm` release name to be overridden. Can be used to assign unique release names when deploying multiple projects to a single namespace. |
| `HELM_UPGRADE_VALUES_FILE`              | From GitLab 12.6, allows the `helm upgrade` values file to be overridden. Defaults to `.gitlab/auto-deploy-values.yaml`. |
| `HELM_UPGRADE_EXTRA_ARGS`               | From GitLab 11.11, allows extra arguments in `helm` commands when deploying the application. Note that using quotes will not prevent word splitting. **Tip:** you can use this variable to [customize the Auto Deploy Helm chart](#custom-helm-chart) by applying custom override values with `--values my-values.yaml`. |
| `INCREMENTAL_ROLLOUT_MODE`              | From GitLab 11.4, if present, can be used to enable an [incremental rollout](#incremental-rollout-to-production-premium) of your application for the production environment. Set to `manual` for manual deployment jobs or `timed` for automatic rollout deployments with a 5 minute delay each one. |
| `K8S_SECRET_*`                          | From GitLab 11.7, any variable prefixed with [`K8S_SECRET_`](#application-secret-variables) will be made available by Auto DevOps as environment variables to the deployed application. |
| `KUBE_INGRESS_BASE_DOMAIN`              | From GitLab 11.8, can be used to set a domain per cluster. See [cluster domains](../../user/project/clusters/index.md#base-domain) for more information. |
| `PRODUCTION_REPLICAS`                   | Number of replicas to deploy in the production environment. Takes precedence over `REPLICAS` and defaults to 1. For zero downtime upgrades, set to 2 or greater. |
| `REPLICAS`                              | Number of replicas to deploy. Defaults to 1. |
| `ROLLOUT_RESOURCE_TYPE`                 | From GitLab 11.9, allows specification of the resource type being deployed when using a custom Helm chart. Default value is `deployment`. |
| `ROLLOUT_STATUS_DISABLED`               | From GitLab 12.0, used to disable rollout status check because it doesn't support all resource types, for example, `cronjob`. |
| `STAGING_ENABLED`                       | From GitLab 10.8, used to define a [deploy policy for staging and production environments](#deploy-policy-for-staging-and-production-environments). |

TIP: **Tip:**
Set up the replica variables using a
[project variable](../../ci/variables/README.md#gitlab-cicd-environment-variables)
and scale your application by just redeploying it!

CAUTION: **Caution:**
You should *not* scale your application using Kubernetes directly. This can
cause confusion with Helm not detecting the change, and subsequent deploys with
Auto DevOps can undo your changes.

### Database

The following table lists variables related to the database.

| **Variable**                            | **Description**                    |
|-----------------------------------------|------------------------------------|
| `DB_INITIALIZE`                         | From GitLab 11.4, used to specify the command to run to initialize the application's PostgreSQL database. Runs inside the application pod. |
| `DB_MIGRATE`                            | From GitLab 11.4, used to specify the command to run to migrate the application's PostgreSQL database. Runs inside the application pod. |
| `POSTGRES_ENABLED`                      | Whether PostgreSQL is enabled. Defaults to `"true"`. Set to `false` to disable the automatic deployment of PostgreSQL. |
| `POSTGRES_USER`                         | The PostgreSQL user. Defaults to `user`. Set it to use a custom username. |
| `POSTGRES_PASSWORD`                     | The PostgreSQL password. Defaults to `testing-password`. Set it to use a custom password. |
| `POSTGRES_DB`                           | The PostgreSQL database name. Defaults to the value of [`$CI_ENVIRONMENT_SLUG`](../../ci/variables/README.md#predefined-environment-variables). Set it to use a custom database name. |
| `POSTGRES_VERSION`                      | Tag for the [`postgres` Docker image](https://hub.docker.com/_/postgres) to use. Defaults to `9.6.2`. |

### Security tools

The following table lists variables related to security tools.

| **Variable**                            | **Description**                    |
|-----------------------------------------|------------------------------------|
| `SAST_CONFIDENCE_LEVEL`                 | Minimum confidence level of security issues you want to be reported; `1` for Low, `2` for Medium, `3` for High. Defaults to `3`. |

### Disable jobs

The following table lists variables used to disable jobs.

| **Variable**                            | **Description**                    |
|-----------------------------------------|------------------------------------|
| `CODE_QUALITY_DISABLED`                 | From GitLab 11.0, used to disable the `codequality` job. If the variable is present, the job will not be created. |
| `CONTAINER_SCANNING_DISABLED`           | From GitLab 11.0, used to disable the `sast:container` job. If the variable is present, the job will not be created. |
| `DAST_DISABLED`                         | From GitLab 11.0, used to disable the `dast` job. If the variable is present, the job will not be created. |
| `DEPENDENCY_SCANNING_DISABLED`          | From GitLab 11.0, used to disable the `dependency_scanning` job. If the variable is present, the job will not be created. |
| `LICENSE_MANAGEMENT_DISABLED`           | From GitLab 11.0, used to disable the `license_management` job. If the variable is present, the job will not be created. |
| `PERFORMANCE_DISABLED`                  | From GitLab 11.0, used to disable the `performance` job. If the variable is present, the job will not be created. |
| `REVIEW_DISABLED`                       | From GitLab 11.0, used to disable the `review` and the manual `review:stop` job. If the variable is present, these jobs will not be created. |
| `SAST_DISABLED`                         | From GitLab 11.0, used to disable the `sast` job. If the variable is present, the job will not be created. |
| `TEST_DISABLED`                         | From GitLab 11.0, used to disable the `test` job. If the variable is present, the job will not be created. |

### Application secret variables

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/49056) in GitLab 11.7.

Some applications need to define secret variables that are
accessible by the deployed application. Auto DevOps detects variables where the key starts with
`K8S_SECRET_` and make these prefixed variables available to the
deployed application, as environment variables.

To configure your application variables:

1. Go to your project's **Settings > CI/CD**, then expand the section
   called **Variables**.

1. Create a CI Variable, ensuring the key is prefixed with
   `K8S_SECRET_`. For example, you can create a variable with key
   `K8S_SECRET_RAILS_MASTER_KEY`.

1. Run an Auto Devops pipeline either by manually creating a new
   pipeline or by pushing a code change to GitLab.

Auto DevOps pipelines will take your application secret variables to
populate a Kubernetes secret. This secret is unique per environment.
When deploying your application, the secret is loaded as environment
variables in the container running the application. Following the
example above, you can see the secret below containing the
`RAILS_MASTER_KEY` variable.

```shell
$ kubectl get secret production-secret -n minimal-ruby-app-54 -o yaml
apiVersion: v1
data:
  RAILS_MASTER_KEY: MTIzNC10ZXN0
kind: Secret
metadata:
  creationTimestamp: 2018-12-20T01:48:26Z
  name: production-secret
  namespace: minimal-ruby-app-54
  resourceVersion: "429422"
  selfLink: /api/v1/namespaces/minimal-ruby-app-54/secrets/production-secret
  uid: 57ac2bfd-03f9-11e9-b812-42010a9400e4
type: Opaque
```

Environment variables are generally considered immutable in a Kubernetes
pod. Therefore, if you update an application secret without changing any
code then manually create a new pipeline, you will find that any running
application pods will not have the updated secrets. In this case, you
can either push a code update to GitLab to force the Kubernetes
Deployment to recreate pods or manually delete running pods to
cause Kubernetes to create new pods with updated secrets.

NOTE: **Note:**
Variables with multiline values are not currently supported due to
limitations with the current Auto DevOps scripting environment.

### Advanced replica variables setup

Apart from the two replica-related variables for production mentioned above,
you can also use others for different environments.

There's a very specific mapping between Kubernetes' label named `track`,
GitLab CI/CD environment names, and the replicas environment variable.
The general rule is: `TRACK_ENV_REPLICAS`. Where:

- `TRACK`: The capitalized value of the `track`
  [Kubernetes label](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
  in the Helm Chart app definition. If not set, it will not be taken into account
  to the variable name.
- `ENV`: The capitalized environment name of the deploy job that is set in
  `.gitlab-ci.yml`.

That way, you can define your own `TRACK_ENV_REPLICAS` variables with which
you will be able to scale the pod's replicas easily.

In the example below, the environment's name is `qa` and it deploys the track
`foo` which would result in looking for the `FOO_QA_REPLICAS` environment
variable:

```yaml
QA testing:
  stage: deploy
  environment:
    name: qa
  script:
  - deploy foo
```

The track `foo` being referenced would also need to be defined in the
application's Helm chart, like:

```yaml
replicaCount: 1
image:
  repository: gitlab.example.com/group/project
  tag: stable
  pullPolicy: Always
  secrets:
    - name: gitlab-registry
application:
  track: foo
  tier: web
service:
  enabled: true
  name: web
  type: ClusterIP
  url: http://my.host.com/
  externalPort: 5000
  internalPort: 5000
```

### Deploy policy for staging and production environments

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ci-yml/-/merge_requests/160) in GitLab 10.8.

TIP: **Tip:**
You can also set this inside your [project's settings](index.md#deployment-strategy).

The normal behavior of Auto DevOps is to use Continuous Deployment, pushing
automatically to the `production` environment every time a new pipeline is run
on the default branch. However, there are cases where you might want to use a
staging environment and deploy to production manually. For this scenario, the
`STAGING_ENABLED` environment variable was introduced.

If `STAGING_ENABLED` is defined in your project (e.g., set `STAGING_ENABLED` to
`1` as a CI/CD variable), then the application will be automatically deployed
to a `staging` environment, and a  `production_manual` job will be created for
you when you're ready to manually deploy to production.

### Deploy policy for canary environments **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ci-yml/-/merge_requests/171) in GitLab 11.0.

A [canary environment](../../user/project/canary_deployments.md) can be used
before any changes are deployed to production.

If `CANARY_ENABLED` is defined in your project (e.g., set `CANARY_ENABLED` to
`1` as a CI/CD variable) then two manual jobs will be created:

- `canary` which will deploy the application to the canary environment
- `production_manual` which is to be used by you when you're ready to manually
  deploy to production.

### Incremental rollout to production **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/5415) in GitLab 10.8.

TIP: **Tip:**
You can also set this inside your [project's settings](index.md#deployment-strategy).

When you have a new version of your app to deploy in production, you may want
to use an incremental rollout to replace just a few pods with the latest code.
This will allow you to first check how the app is behaving, and later manually
increasing the rollout up to 100%.

If `INCREMENTAL_ROLLOUT_MODE` is set to `manual` in your project, then instead
of the standard `production` job, 4 different
[manual jobs](../../ci/pipelines/index.md#add-manual-interaction-to-your-pipeline)
will be created:

1. `rollout 10%`
1. `rollout 25%`
1. `rollout 50%`
1. `rollout 100%`

The percentage is based on the `REPLICAS` variable and defines the number of
pods you want to have for your deployment. If you say `10`, and then you run
the `10%` rollout job, there will be `1` new pod + `9` old ones.

To start a job, click on the play icon next to the job's name. You are not
required to go from `10%` to `100%`, you can jump to whatever job you want.
You can also scale down by running a lower percentage job, just before hitting
`100%`. Once you get to `100%`, you cannot scale down, and you'd have to roll
back by redeploying the old version using the
[rollback button](../../ci/environments.md#retrying-and-rolling-back) in the
environment page.

Below, you can see how the pipeline will look if the rollout or staging
variables are defined.

Without `INCREMENTAL_ROLLOUT_MODE` and without `STAGING_ENABLED`:

![Staging and rollout disabled](img/rollout_staging_disabled.png)

Without `INCREMENTAL_ROLLOUT_MODE` and with `STAGING_ENABLED`:

![Staging enabled](img/staging_enabled.png)

With `INCREMENTAL_ROLLOUT_MODE` set to `manual` and without `STAGING_ENABLED`:

![Rollout enabled](img/rollout_enabled.png)

With `INCREMENTAL_ROLLOUT_MODE` set to `manual` and with `STAGING_ENABLED`

![Rollout and staging enabled](img/rollout_staging_enabled.png)

CAUTION: **Caution:**
Before GitLab 11.4 this feature was enabled by the presence of the
`INCREMENTAL_ROLLOUT_ENABLED` environment variable.
This configuration is deprecated and will be removed in the future.

### Timed incremental rollout to production **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/7545) in GitLab 11.4.

TIP: **Tip:**
You can also set this inside your [project's settings](index.md#deployment-strategy).

This configuration is based on
[incremental rollout to production](#incremental-rollout-to-production-premium).

Everything behaves the same way, except:

- It's enabled by setting the `INCREMENTAL_ROLLOUT_MODE` variable to `timed`.
- Instead of the standard `production` job, the following jobs are created with a 5 minute delay between each :
  1. `timed rollout 10%`
  1. `timed rollout 25%`
  1. `timed rollout 50%`
  1. `timed rollout 100%`

## Auto DevOps banner

The following Auto DevOps banner will show for maintainers+ on new projects when Auto DevOps is not
enabled:

![Auto DevOps banner](img/autodevops_banner_v12_6.png)

The banner can be disabled for:

- A user when they dismiss it themselves.
- A project by explicitly [disabling Auto DevOps](index.md#enablingdisabling-auto-devops).
- An entire GitLab instance:
  - By an administrator running the following in a Rails console:

    ```ruby
    Feature.get(:auto_devops_banner_disabled).enable
    ```

  - Through the REST API with an admin access token:

    ```shell
    curl --data "value=true" --header "PRIVATE-TOKEN: <personal_access_token>" https://gitlab.example.com/api/v4/features/auto_devops_banner_disabled
    ```
